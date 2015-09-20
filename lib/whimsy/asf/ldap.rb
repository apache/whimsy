require 'wunderbar'
require 'ldap'

module ASF
  # determine where ldap.conf resides
  if Dir.exist? '/etc/openldap'
    ETCLDAP = '/etc/openldap'
  else
    ETCLDAP = '/etc/ldap'
  end

  # determine whether or not the LDAP API can be used
  def self.init_ldap
    @ldap = nil
    @mtime = Time.now

    host = ASF::LDAP.host

    Wunderbar.info "Connecting to LDAP server: #{host}"

    begin
      uri = URI.parse(host)
      if uri.scheme == 'ldaps'
        @ldap = ::LDAP::SSLConn.new(uri.host, uri.port)
      else
        @ldap = ::LDAP::Conn.new(uri.host, uri.port)
      end
    rescue ::LDAP::ResultError=>re
      Wunderbar.error "Error binding to LDAP server: message: ["+ re.message + "]"
    end
  end

  def self.ldap
    @ldap || self.init_ldap
  end

  # search with a scope of one
  def self.search_one(base, filter, attrs=nil)
    init_ldap unless defined? @ldap
    return [] unless @ldap

    Wunderbar.info "ldapsearch -x -LLL -b #{base} -s one #{filter} " +
      "#{[attrs].flatten.join(' ')}"
    
    begin
      result = @ldap.search2(base, ::LDAP::LDAP_SCOPE_ONELEVEL, filter, attrs)
    rescue
      result = []
    end

    result.map! {|hash| hash[attrs]} if String === attrs

    result
  end

  def self.refresh(symbol)
    if Time.now - @mtime > 300.0
      @mtime = Time.now
    end

    if instance_variable_get("#{symbol}_mtime") != @mtime
      instance_variable_set("#{symbol}_mtime", @mtime)
      instance_variable_set(symbol, nil)
    end
  end

  def self.pmc_chairs
    refresh(:@pmc_chairs)
    @pmc_chairs ||= Service.find('pmc-chairs').members
  end

  def self.committers
    refresh(:@committers)
    @committers ||= Group.find('committers').members
  end

  def self.members
    refresh(:@members)
    @members ||= Group.find('member').members
  end

  class Base
    attr_reader :name

    def self.base
      @base
    end

    def base
      self.class.base
    end

    def self.collection
      @collection ||= Hash.new
    end

    def self.[] name
      collection[name] || new(name)
    end

    def self.find name
      collection[name] || new(name)
    end

    def self.new name
      collection[name] || super
    end

    def initialize name
      self.class.collection[name] = self
      @name = name
    end

    unless Object.respond_to? :id
      def id
        @name
      end
    end
  end

  class LazyHash < Hash
    def initialize(&initializer)
      @initializer = initializer
    end

    def load
     return unless @initializer
     merge! @initializer.call || {}
     @initializer = super
    end

    def [](key)
      result = super
      if not result and not keys.include? key and @initializer
        merge! @initializer.call || {}
        @initializer = nil
        result = super
      end
      result
    end
  end

  class Person < Base
    @base = 'ou=people,dc=apache,dc=org'

    def self.list(filter='uid=*')
      ASF.search_one(base, filter, 'uid').flatten.map {|uid| find(uid)}
    end

    # pre-fetch a given attribute, for a given list of people
    def self.preload(attributes, people={})
      attributes = [attributes].flatten

      if people.empty?
        filter = "(|#{attributes.map {|attribute| "(#{attribute}=*)"}.join})"
      else
        filter = "(|#{people.map {|person| "(uid=#{person.name})"}.join})"
      end
      
      zero = Hash[attributes.map {|attribute| [attribute,nil]}]

      data = ASF.search_one(base, filter, attributes + ['uid'])
      data = Hash[data.map! {|hash| [find(hash['uid'].first), hash]}]
      data.each {|person, hash| person.attrs.merge!(zero.merge(hash))}

      if people.empty?
        (collection.values - data.keys).each do |person| 
          person.attrs.merge! zero
        end
      end
    end

    def attrs
      @attrs ||= LazyHash.new {ASF.search_one(base, "uid=#{name}").first}
    end

    def public_name
      return icla.name if icla
      cn = [attrs['cn']].flatten.first
      cn.force_encoding('utf-8') if cn.respond_to? :force_encoding
      return cn if cn
      ASF.search_archive_by_id(name)
    end

    def asf_member?
      ASF::Member.status[name] or ASF.members.include? self
    end

    def asf_committer?
       ASF::Group.new('committers').include? self
    end

    def banned?
      not attrs['loginShell'] or attrs['loginShell'].include? "/usr/bin/false"
    end

    def mail
      attrs['mail'] || []
    end

    def alt_email
      attrs['asf-altEmail'] || []
    end

    def pgp_key_fingerprints
      attrs['asf-pgpKeyFingerprint']
    end

    def urls
      attrs['asf-personalURL'] || []
    end

    def committees
      Committee.list("member=uid=#{name},#{base}")
    end

    def groups
      Group.list("memberUid=#{name}")
    end

    def dn
      value = attrs['dn']
      value.first if Array === value
    end

    def method_missing(name, *args)
      if name.to_s.end_with? '=' and args.length == 1
        return modify(name.to_s[0..-2], args)
      end

      return super unless args.empty?
      result = self.attrs[name.to_s]
      return super unless result

      if result.empty?
        return nil
      else
        result.map! do |value|
          value = value.dup.force_encoding('utf-8') if String === value
          value
        end

        if result.length == 1
          result.first
        else
          result
        end
      end
    end

    def modify(attr, value)
      value = Array(value) unless Hash === value
      mod = ::LDAP::Mod.new(::LDAP::LDAP_MOD_REPLACE, attr.to_s, value)
      ASF.ldap.modify(self.dn, [mod])
      attrs[attr.to_s] = value
    end
  end

  class Group < Base
    @base = 'ou=groups,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| find(cn)}
    end

    def include?(person)
      filter = "(&(cn=#{name})(memberUid=#{person.name}))"
      if ASF.search_one(base, filter, 'cn').empty?
        return false
      else
        return true
      end
    end

    def members
      ASF.search_one(base, "cn=#{name}", 'memberUid').flatten.
        map {|uid| Person.find(uid)}
    end
  end

  class Committee < Base
    @base = 'ou=pmc,ou=committees,ou=groups,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| Committee.find(cn)}
    end

    def members
      ASF.search_one(base, "cn=#{name}", 'member').flatten.
        map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first
    end
  end

  class Service < Base
    @base = 'ou=groups,ou=services,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten
    end

    def dn
      "cn=#{id},#{self.class.base}"
    end

    def members
      ASF.search_one(base, "cn=#{name}", 'member').flatten.
        map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    def remove(people)
      people = Array(people).map(&:dn)
      mod = ::LDAP::Mod.new(::LDAP::LDAP_MOD_DELETE, 'member', people)
      ASF.ldap.modify(self.dn, [mod])
    end

    def add(people)
      people = Array(people).map(&:dn)
      mod = ::LDAP::Mod.new(::LDAP::LDAP_MOD_ADD, 'member', people)
      ASF.ldap.modify(self.dn, [mod])
    end
  end

  module LDAP
    def self.bind(user, password, &block)
      dn = ASF::Person.new(user).dn
      if block
        ASF.ldap.bind(dn, password, &block)
      else
        ASF.ldap.bind(dn, password)
      end
      ASF.init_ldap
    end

    # select LDAP host
    def self.host
      # try whimsy config
      host = ASF::Config.get(:ldap)

      # check system configuration
      unless host
        conf = "#{ETCLDAP}/ldap.conf"
        if File.exist? conf
          host = File.read(conf)[/^uri\s+(ldaps?:\/\/\S+?:\d+)/i, 1]
        end
      end

      # if all else fails, pick one at random
      unless host
        # https://www.pingmybox.com/dashboard?location=304
        host = %w(ldaps://ldap1-us-west.apache.org:636
          ldaps://ldap1-eu-central.apache.org:636
          ldaps://ldap2-us-west.apache.org:636
          ldaps://ldap1-us-east.apache.org:636).sample
      end

      host
    end

    # query and extract cert from openssl output
    def self.cert
      host = LDAP.host[%r{//(.*?)(/|$)}, 1]
      query = "openssl s_client -connect #{host} -showcerts"
      output = `#{query} < /dev/null 2> /dev/null`
      output[/^-+BEGIN.*?\n-+END[^\n]+\n/m]
    end

    # update /etc/ldap.conf. Usage:
    #   sudo ruby -r whimsy/asf -e "ASF::LDAP.configure"
    def self.configure
      if not File.exist? "#{ETCLDAP}/asf-ldap-client.pem"
        File.write "#{ETCLDAP}/asf-ldap-client.pem", self.cert
      end

      ldap_conf = "#{ETCLDAP}/ldap.conf"
      content = File.read(ldap_conf)
      unless content.include? 'asf-ldap-client.pem'
        content.gsub!(/^TLS_CACERT/, '# TLS_CACERT')
        content.gsub!(/^TLS_REQCERT/, '# TLS_REQCERT')
        content += "TLS_CACERT #{ETCLDAP}/asf-ldap-client.pem\n"
        content += "uri #{LDAP.host}\n"
        content += "base dc=apache,dc=org\n"
        content += "TLS_REQCERT allow\n" if ETCLDAP.include? 'openldap'
        File.write(ldap_conf, content)
      end
    end
  end
end
