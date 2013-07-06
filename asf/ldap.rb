require 'wunderbar'
require 'rubygems'
require 'ldap'

module ASF

  # determine whether or not the LDAP API can be used
  def self.init_ldap
    @ldap = nil
    begin
      conf = '/etc/ldap/ldap.conf'
      host = File.read(conf).scan(/^uri\s+ldaps:\/\/(\S+?):(\d+)/i).first
      if host
         Wunderbar.info "Connecting to LDAP server: [ldaps://#{host[0]}:#{host[1]}]"
      end
    rescue Errno::ENOENT
      host = nil
      Wunderbar.error "No LDAP server defined, there must be a LDAP ldaps:// URI in /etc/ldap/ldap.conf"
    end
    begin
      @ldap = LDAP::SSLConn.new(host.first, host.last.to_i)
    rescue LDAP::ResultError=>re
      Wunderbar.error "Error binding to LDAP server: message: ["+ re.message + "]"
    end
  end

  # search with a scope of one
  def self.search_one(base, filter, attrs=nil)
    init_ldap unless defined? @ldap

    Wunderbar.info "ldapsearch -x -LLL -b #{base} -s one #{filter} " +
      "#{[attrs].flatten.join(' ')}"
    
    result = @ldap.search2(base, LDAP::LDAP_SCOPE_ONELEVEL, filter, attrs)

    result.map! {|hash| hash[attrs]} if String === attrs

    result
  end

  def self.pmc_chairs
    @pmc_chairs ||= Service.find('pmc-chairs').members
  end

  def self.committers
    @committers ||= Group.find('committers').members
  end

  def self.members
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
      name.untaint if name =~ /\A\w+\Z/
      @attrs ||= LazyHash.new {ASF.search_one(base, "uid=#{name}").first}
    end

    def public_name
      cn = [attrs['cn']].flatten.first
      cn.force_encoding('utf-8') if cn.respond_to? :force_encoding
      return cn if cn
      return icla.name if icla
      ASF.search_archive_by_id(name)
    end

    def asf_member?
      ASF::Member.status[name] or ASF.members.include? self
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
  end

  class Group < Base
    @base = 'ou=groups,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| find(cn)}
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
      name.untaint if name =~ /\A\w+\Z/
      ASF.search_one(base, "cn=#{name}", 'member').flatten.
        map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end
  end

  class Service < Base
    @base = 'ou=groups,ou=services,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten
    end

    def members
      ASF.search_one(base, "cn=#{name}", 'member').flatten.
        map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end
  end
end
