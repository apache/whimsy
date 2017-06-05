#
# Encapsulate access to LDAP, caching results for performance.  For best
# performance in applications that access large number of objects, make use
# of the preload methods to pre-fetch multiple objects in a single LDAP
# call, and rely on the cache to find the objects later.
#
# The cache makes heavy use of Weak References internally to enable garbage
# collection to reclaim objects; among other things, this ensures that
# LDAP results don't become too stale.
#
# Until garbage collection reclaims an object, calls to find methods for the
# same name is guaranteed to return the same object.  Holding on to the
# results of find or preload calls (by assigning it to a variable) is
# sufficient to prevent reclaiming of objects.
#
# To illustrate, the following is likely to return the same id twice, followed
# by a new id:
#   puts ASF::Person.find('rubys').__id__
#   puts ASF::Person.find('rubys').__id__
#   GC.start
#   puts ASF::Person.find('rubys').__id__
#
# By contrast, the following is guaranteed to produce the same id three times:
#   rubys1 = ASF::Person.find('rubys')
#   rubys2 = ASF::Person.find('rubys')
#   GC.start
#   rubys3 = ASF::Person.find('rubys')
#   puts [rubys1.__id__, rubys2.__id__, rubys3.__id__]
#

require 'wunderbar'
require 'ldap'
require 'weakref'
require 'net/http'
require 'base64'
require 'thread'

module ASF
  module LDAP
     # https://www.pingmybox.com/dashboard?location=304
     # https://github.com/apache/infrastructure-puppet/blob/deployment/data/common.yaml (ldapserver::slapd_peers)
     # Updated 2017-01-02 
    HOSTS = %w(
      ldaps://themis.apache.org:636
      ldaps://ldap1-lw-us.apache.org:636
      ldaps://ldap1-lw-eu.apache.org:636
      ldaps://devops.apache.org:636
      ldaps://snappy5.apache.org:636
    )

    CONNECT_LOCK = Mutex.new
    HOST_QUEUE = Queue.new

    # fetch configuration from apache/infrastructure-puppet
    def self.puppet_config
      return @puppet if @puppet
      file = '/apache/infrastructure-puppet/deployment/data/common.yaml'
      http = Net::HTTP.new('raw.githubusercontent.com', 443)
      http.use_ssl = true
      # the enclosing method is optional, so we only require the gem here
      require 'yaml'
      @puppet = YAML.load(http.request(Net::HTTP::Get.new(file)).body)
    end

    # extract the ldapcert from the puppet configuration
    def self.puppet_cert
      puppet_config['ldapclient::ldapcert']
    end

    # extract the ldap servers from the puppet configuration
    def self.puppet_ldapservers
      puppet_config['ldapserver::slapd_peers'].values.
        map {|host| "ldaps://#{host}:636"}
    rescue
      nil
    end

    # connect to LDAP
    def self.connect(test = true)
      # Try each host at most once
      hosts.length.times do
        # Ensure we use each host in turn
        hosts.each {|host| HOST_QUEUE.push host} if HOST_QUEUE.empty?
        host = HOST_QUEUE.shift

        Wunderbar.info "[#{host}] - Connecting to LDAP server"

        begin
          # request connection
          uri = URI.parse(host)
          if uri.scheme == 'ldaps'
            ldap = ::LDAP::SSLConn.new(uri.host, uri.port)
          else
            ldap = ::LDAP::Conn.new(uri.host, uri.port)
          end

          # test the connection
          ldap.bind if test

          # save the host
          @host = host

          return ldap
        rescue ::LDAP::ResultError => re
          Wunderbar.warn "[#{host}] - Error connecting to LDAP server: " +
            re.message + " (continuing)"
        end

      end

      Wunderbar.error "Failed to connect to any LDAP host"
      return nil
    end

    def self.bind(user, password, &block)
      dn = ASF::Person.new(user).dn
      raise ::LDAP::ResultError.new('Unknown user') unless dn

      ASF.ldap.unbind if ASF.ldap.bound? rescue nil
      ldap = ASF.init_ldap(true)
      if block
        ldap.bind(dn, password, &block)
        ASF.init_ldap(true)
      else
        ldap.bind(dn, password)
      end
    end

    # validate HTTP authorization, and optionally invoke a block bound to
    # that user.
    def self.http_auth(string, &block)
      auth = Base64.decode64(string.to_s[/Basic (.*)/, 1] || '')
      user, password = auth.split(':', 2)
      return unless password

      if block
        self.bind(user, password, &block)
      else
        begin
          ASF::LDAP.bind(user, password) {}
          return ASF::Person.new(user)
        rescue ::LDAP::ResultError
          return nil
        end
      end
    end

    # Return the last chosen host (if any)
    def self.host
      @host
    end

    # determine what LDAP hosts are available
    def self.hosts
      return @hosts if @hosts # cache the hosts list
      # try whimsy config
      hosts = Array(ASF::Config.get(:ldap))

      # check system configuration
      if hosts.empty?
        conf = "#{ETCLDAP}/ldap.conf"
        if File.exist? conf
          uris = File.read(conf)[/^uri\s+(.*)/i, 1].to_s
          hosts = uris.scan(/ldaps?:\/\/\S+?:\d+/)
          Wunderbar.debug "Using hosts from LDAP config"
        end
      else
        Wunderbar.debug "Using hosts from Whimsy config"
      end

      # if all else fails, use default list
      Wunderbar.debug "Using default host list" if hosts.empty?
      hosts = ASF::LDAP::HOSTS if hosts.empty?

      hosts.shuffle!
      #Wunderbar.debug "Hosts:\n#{hosts.join(' ')}"
      @hosts = hosts
    end

    # query and extract cert from openssl output
    def self.extract_cert
      host = hosts.sample[%r{//(.*?)(/|$)}, 1]
      puts ['openssl', 's_client', '-connect', host, '-showcerts'].join(' ')
      out, err, rc = Open3.capture3 'openssl', 's_client',
        '-connect', host, '-showcerts'
      out[/^-+BEGIN.*?\n-+END[^\n]+\n/m]
    end

    # update /etc/ldap.conf. Usage:
    #
    #   sudo ruby -r whimsy/asf -e "ASF::LDAP.configure"
    #
    def self.configure
      cert = Dir["#{ETCLDAP}/asf*-ldap-client.pem"].first

      # verify/obtain/write the cert
      if not cert
        cert = "#{ETCLDAP}/asf-ldap-client.pem"
        File.write cert, ASF::LDAP.puppet_cert || self.extract_cert
      end

      # read the current configuration file
      ldap_conf = "#{ETCLDAP}/ldap.conf"
      content = File.read(ldap_conf)

      # ensure that the right cert is used
      unless content =~ /asf.*-ldap-client\.pem/
        content.gsub!(/^TLS_CACERT/i, '# TLS_CACERT')
        content += "TLS_CACERT #{ETCLDAP}/asf-ldap-client.pem\n"
      end

      # provide the URIs of the ldap hosts
      content.gsub!(/^URI/, '# URI')
      content += "uri \n" unless content =~ /^uri /
      content[/uri (.*)\n/, 1] = hosts.join(' ')

      # verify/set the base
      unless content.include? 'base dc=apache'
        content.gsub!(/^BASE/i, '# BASE')
        content += "base dc=apache,dc=org\n"
      end

      # ensure TLS_REQCERT is allow (Mac OS/X only)
      if ETCLDAP.include? 'openldap' and not content.include? 'REQCERT allow'
        content.gsub!(/^TLS_REQCERT/i, '# TLS_REQCERT')
        content += "TLS_REQCERT allow\n"
      end

      # write the configuration if there were any changes
      File.write(ldap_conf, content) unless content == File.read(ldap_conf)
    end

    # dump more information on LDAP errors - modify
    def self.modify(dn, list)
      ASF.ldap.modify(dn, list)
    rescue ::LDAP::ResultError
      Wunderbar.warn(list.inspect)
      Wunderbar.warn(dn.to_s)
      raise
    end

    # dump more information on LDAP errors - add
    def self.add(dn, list)
      ASF.ldap.add(dn, list)
    rescue ::LDAP::ResultError
      Wunderbar.warn(list.inspect)
      Wunderbar.warn(dn.to_s)
      raise
    end

    # dump more information on LDAP errors - delete
    def self.delete(dn)
      ASF.ldap.delete(dn)
    rescue ::LDAP::ResultError
      Wunderbar.warn(list.inspect)
      Wunderbar.warn(dn.to_s)
      raise
    end
  end

  # public entry point for establishing a connection safely
  def self.init_ldap(reset = false)
    ASF::LDAP::CONNECT_LOCK.synchronize do
      @ldap = nil if reset
      @ldap ||= ASF::LDAP.connect(!reset)
    end
  end

  # determine where ldap.conf resides
  if Dir.exist? '/etc/openldap'
    ETCLDAP = '/etc/openldap'
  else
    ETCLDAP = '/etc/ldap'
  end
  # Note: FreeBSD seems to use
  # /usr/local/etc/openldap/ldap.conf

  def self.ldap
    @ldap || self.init_ldap
  end

  # search with a scope of one, with automatic retry/failover
  def self.search_one(base, filter, attrs=nil)
    self.search_scope(::LDAP::LDAP_SCOPE_ONELEVEL, base, filter, attrs)
  end

  # search with a scope of subtree, with automatic retry/failover
  def self.search_subtree(base, filter, attrs=nil)
    self.search_scope(::LDAP::LDAP_SCOPE_SUBTREE, base, filter, attrs)
  end

  # search with a specified scope, with automatic retry/failover
  def self.search_scope(scope, base, filter, attrs=nil)

    # Dummy command, used for logging purposes only
    sname = %w(base one sub children)[scope] rescue scope
    cmd = "ldapsearch -x -LLL -b #{base} -s #{sname} #{filter} " +
      "#{[attrs].flatten.join(' ')}"

    # try once per host, with a minimum of two tries
    attempts_left = [ASF::LDAP.hosts.length, 2].max
    begin
      attempts_left -= 1
      init_ldap unless @ldap
      return [] unless @ldap

      target = @ldap.get_option(::LDAP::LDAP_OPT_HOST_NAME) rescue '?'
      Wunderbar.info "[#{target}] #{cmd}"

      result = @ldap.search2(base, scope, filter, attrs)
    rescue Exception => re
      if attempts_left <= 0
        Wunderbar.error "[#{target}] => #{re.inspect} for #{cmd}"
        raise
      else
        Wunderbar.warn "[#{target}] => #{re.inspect} for #{cmd}, retrying ..."
        @ldap.unbind if @ldap.bound? rescue nil
        @ldap = nil # force new connection
        sleep 1
        retry
      end
    end

    result.map! {|hash| hash[attrs]} if String === attrs

    result.compact
  end

  # safely dereference a weakref array attribute.  Block provided is
  # used when reference is not set or has been reclaimed.
  def self.dereference_weakref(object, attr, &block)
    attr = "@#{attr}"
    value = object.instance_variable_get(attr) || block.call
    value[0..-1]
  rescue WeakRef::RefError
    value = block.call
  ensure
    if not value or RUBY_VERSION.start_with? '1'
      object.instance_variable_set(attr, value)
    elsif value and not value.instance_of? WeakRef
      object.instance_variable_set(attr, WeakRef.new(value))
    end
  end

  def self.weakref(attr, &block)
    self.dereference_weakref(self, attr, &block)
  end

  def self.pmc_chairs
    weakref(:pmc_chairs) {Service.find('pmc-chairs').members}
  end

  def self.committers
    weakref(:committers) {Group.find('committers').members}
  end

  def self.members
    weakref(:members) {Group.find('member').members}
  end

  class Base
    attr_reader :name

    # define default sort key (make Base objects sortable)
    def <=>(other)
      @name <=> other.name
    end

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
      new(name)
    end

    def self.find name
      new(name)
    end

    def self.new name
      begin
        object = collection[name]
        return object.reference if object and object.weakref_alive?
      rescue
      end

      super
    end

    def initialize name
      self.class.collection[name] = WeakRef.new(self)
      @name = name
    end

    def reference
      self
    end

    def weakref(attr, &block)
      ASF.dereference_weakref(self, attr, &block)
    end

    unless Object.respond_to? :id
      def id
        @name
      end
    end

    def self.mod_add(attr, vals)
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_ADD, attr.to_s, Array(vals))
    end

    def self.mod_replace(attr, vals)
      vals = Array(vals) unless Hash === vals
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_REPLACE, attr.to_s, vals)
    end

    def self.mod_delete(attr, vals)
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_DELETE, attr.to_s, Array(vals))
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
      list = Hash.new {|hash, name| hash[name] = find(name)}

      attributes = [attributes].flatten

      if people.empty?
        filter = "(|#{attributes.map {|attribute| "(#{attribute}=*)"}.join})"
      else
        filter = "(|#{people.map {|person| "(uid=#{person.name})"}.join})"
      end
      
      zero = Hash[attributes.map {|attribute| [attribute,nil]}]

      data = ASF.search_one(base, filter, attributes + ['uid'])
      data = Hash[data.map! {|hash| [list[hash['uid'].first], hash]}]
      data.each {|person, hash| person.attrs.merge!(zero.merge(hash))}

      if people.empty?
        (list.values - data.keys).each do |person|
          person.attrs.merge! zero
        end
      end

      list.values
    end

    # return person only if it actually exits
    def self.[] name
      person = super
      person.attrs['dn'] ? person : nil
    end

    def attrs
      @attrs ||= LazyHash.new {ASF.search_one(base, "uid=#{name}").first}
    end

    def reload!
      @attrs = nil
      attrs
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

    def asf_officer_or_member?
      asf_member? or ASF.pmc_chairs.include? self
    end

    def asf_committer?
       ASF::Group.new('committers').include? self
    end

    def banned?
      # FreeBSD uses /usr/bin/false; Ubuntu uses /bin/false
      not attrs['loginShell'] or %w(/bin/false bin/nologin bin/no-cla).any? {|a| attrs['loginShell'].first.include? a}
    end

    def mail
      attrs['mail'] || []
    end

    def alt_email
      attrs['asf-altEmail'] || []
    end

    def pgp_key_fingerprints
      attrs['asf-pgpKeyFingerprint'] || []
    end

    def ssh_public_keys
      attrs['sshPublicKey'] || []
    end

    def urls
      attrs['asf-personalURL'] || []
    end

    def committees
      weakref(:committees) do
        Committee.list("member=uid=#{name},#{base}")
      end
    end

    def projects
      weakref(:projects) do
        Project.list("member=uid=#{name},#{base}")
      end
    end

    def groups
      weakref(:groups) do
        Group.list("memberUid=#{name}")
      end
    end

    def services
      weakref(:services) do
        Service.list("member=#{dn}")
      end
    end

    def dn
      "uid=#{name},#{ASF::Person.base}"
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
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_replace(attr.to_s, value)])
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

    def self.preload
      Hash[ASF.search_one(base, "cn=*", %w(dn memberUid modifyTimestamp createTimestamp)).map do |results|
        cn = results['dn'].first[/^cn=(.*?),/, 1]
        group = ASF::Group.find(cn)
        group.modifyTimestamp = results['modifyTimestamp'].first # it is returned as an array of 1 entry
        group.createTimestamp = results['createTimestamp'].first # it is returned as an array of 1 entry
        members = results['memberUid']  || []
        group.members = members
        [group, members]
      end]
    end

    attr_accessor :modifyTimestamp, :createTimestamp

    # return group only if it actually exits
    def self.[] name
      group = super
      group.members.empty? ? nil : group
    end

    def members=(members)
      @members = WeakRef.new(members)
    end

    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'memberUid').flatten
      end

      members.map {|uid| Person.find(uid)}
    end

    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first
    end

    # remove people from an existing group
    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:id)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('memberUid', people)])
    ensure
      @members = nil
    end

    # add people to an existing group
    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:id)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('memberUid', people)])
    ensure
      @members = nil
    end

    # add a new group
    def self.add(name, people)
      nextgid = ASF::search_one(ASF::Group.base, 'cn=*', 'gidNumber').
        flatten.map(&:to_i).max + 1

      entry = [
        mod_add('objectClass', ['posixGroup', 'top']),
        mod_add('cn', name),
        mod_add('userPassword', '{crypt}*'),
        mod_add('gidNumber', nextgid.to_s),
        mod_add('memberUid', people.map(&:id))
      ]

      ASF::LDAP.add("cn=#{name},#{base}", entry)
    end

    # remove a group
    def self.remove(name)
      ASF::LDAP.delete("cn=#{name},#{base}")
    end
  end

  # Ultimately, this will include both PMCs and PPMCs, and enable separate
  # updating of owners and members.  For now this is only used for PPMCs
  # and owners and members are kept in sync.
  class Project < Base
    @base = 'ou=project,ou=groups,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| Project.find(cn)}
    end

    def self.preload
      Hash[ASF.search_one(base, "cn=*", %w(dn member owner modifyTimestamp createTimestamp)).map do |results|
        cn = results['dn'].first[/^cn=(.*?),/, 1]
        project = self.find(cn)
        project.modifyTimestamp = results['modifyTimestamp'].first # it is returned as an array of 1 entry
        project.createTimestamp = results['createTimestamp'].first # it is returned as an array of 1 entry
        members = results['member'] || []
        owners = results['owner'] || []
        project.members = members
        project.owners = owners
        [project, [members, owners]] # TODO is this correct? it seems to work...
      end]
    end

    attr_accessor :modifyTimestamp, :createTimestamp

    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first rescue nil
    end

    # create an LDAP group for this project
    def create(owners, committers=nil)
      owners = Array(owners).map(&:dn)
      committers = Array(committers || owners).map(&:dn)

      entry = [
        ASF::Base.mod_add('objectClass', ['groupOfNames', 'top']),
        ASF::Base.mod_add('cn', name), 
        ASF::Base.mod_add('owner', owners),
        ASF::Base.mod_add('member', committers),
      ]

      ASF::LDAP.add("cn=#{name},#{base}", entry)

      self.owners = owners
      self.members = committers
    end

    def members=(members)
      @members = WeakRef.new(members)
    end

    def owners=(owners)
      @owners = WeakRef.new(owners)
    end

    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    def owners
      owners = weakref(:owners) do
        ASF.search_one(base, "cn=#{name}", 'owner').flatten
      end

      owners.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # remove people from a project as owners and members
    def remove(people)
      remove_owners(people)
      remove_members(people)
    end

    # remove people as owners of a project
    def remove_owners(people)
      @owners = nil
      removals = (Array(people) & owners).map(&:dn)
      unless removals.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('owner', removals)])
      end
    ensure
      @owners = nil
    end

    # remove people as members of a project
    def remove_members(people)
      @members = nil
      removals = (Array(people) & members).map(&:dn)
      unless removals.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', removals)])
      end
    ensure
      @members = nil
    end

    # add people to a project as members and owners
    def add(people)
      add_owners(people)
      add_members(people)
    end

    # add people as owners of a project
    def add_owners(people)
      @owners = nil
      additions = (Array(people) - owners).map(&:dn)
      unless additions.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('owner', additions)])
      end
    ensure
      @owners = nil
    end

    # add people as members of a project
    def add_members(people)
      @members = nil
      additions = (Array(people) - members).map(&:dn)
      unless additions.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', additions)])
      end
    ensure
      @members = nil
    end
  end

  class Committee < Base
    @base = 'ou=pmc,ou=committees,ou=groups,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| Committee.find(cn)}
    end

    def self.preload
      Hash[ASF.search_one(base, "cn=*", %w(dn member modifyTimestamp createTimestamp)).map do |results|
        cn = results['dn'].first[/^cn=(.*?),/, 1]
        committee = ASF::Committee.find(cn)
        committee.modifyTimestamp = results['modifyTimestamp'].first # it is returned as an array of 1 entry
        committee.createTimestamp = results['createTimestamp'].first # it is returned as an array of 1 entry
        members = results['member'] || []
        committee.members = members
        [committee, members]
      end]
    end

    attr_accessor :modifyTimestamp, :createTimestamp

    # return committee only if it actually exits
    def self.[] name
      committee = super
      committee.members.empty? ? nil : committee
    end

    def members=(members)
      @members = WeakRef.new(members)
    end

    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # transitional methods
    def owners
      if name == 'incubator'
        ASF::Project.find('incubator').owners
      else
        members
      end
    end

    def committers
      if name == 'incubator'
        ASF::Project.find('incubator').members
      else
        ASF::Group.find(name).members
      end
    end

    # remove people as owners of a project
    def remove_owners(people)
      if name == 'incubator'
        ASF::Project.find('incubator').remove_owners(people)
      else
        remove(people)
      end
    end

    # remove people as members of a project
    def remove_committers(people)
      if name == 'incubator'
        ASF::Project.find('incubator').remove_members(people)
      else
        ASF::Group.find(name).remove(people)
      end
    end

    # add people as owners of a project
    def add_owners(people)
      if name == 'incubator'
        ASF::Project.find('incubator').add_owners(people)
      else
        add(people)
      end
    end

    # add people as members of a project
    def add_committers(people)
      if name == 'incubator'
        ASF::Project.find('incubator').add_members(people)
      else
        ASF::Group.find(name).add(people)
      end
    end

    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first
    end

    # remove people from a committee
    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:dn)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', people)])
    ensure
      @members = nil
    end

    # add people to a committee
    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:dn)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', people)])
    ensure
      @members = nil
    end

    # add a new committee
    def self.add(name, people)
      entry = [
        mod_add('objectClass', ['groupOfNames', 'top']),
        mod_add('cn', name),
        mod_add('member', Array(people).map(&:dn))
      ]

      ASF::LDAP.add("cn=#{name},#{base}", entry)
    end

    # remove a committee
    def self.remove(name)
      ASF::LDAP.delete("cn=#{name},#{base}")
    end
  end

  class Service < Base
    @base = 'ou=groups,ou=services,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten
    end

    def dn
      return @dn if @dn
      dns = ASF.search_subtree(self.class.base, "cn=#{name}", 'dn')
      @dn = dns.first.first unless dns.empty?
      @dn
    end

    def base
      if dn
        dn.sub(/^cn=.*?,/, '')
      else
        super
      end
    end

    def self.preload
      Hash[ASF.search_one(base, "cn=*", %w(dn member modifyTimestamp createTimestamp)).map do |results|
        cn = results['dn'].first[/^cn=(.*?),/, 1]
        service = self.find(cn)
        service.modifyTimestamp = results['modifyTimestamp'].first # it is returned as an array of 1 entry
        service.createTimestamp = results['createTimestamp'].first # it is returned as an array of 1 entry
        members = results['member'] || []
        service.members = members
        [service, members]
      end]
    end

    attr_accessor :modifyTimestamp, :createTimestamp

    def members=(members)
      @members = WeakRef.new(members)
    end

    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:dn)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', people)])
    ensure
      @members = nil
    end

    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:dn)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', people)])
    ensure
      @members = nil
    end
  end

  class AppGroup < Service
    @base = 'ou=apps,ou=groups,dc=apache,dc=org'
  end

  class AuthGroup < Service
    @base = 'ou=auth,ou=groups,dc=apache,dc=org'
  end

end

if __FILE__ == $0
  module ASF
    module LDAP
      def self.getHOSTS
        HOSTS
      end
    end
  end
  hosts=ASF::LDAP.getHOSTS().sort!
  puppet=ASF::LDAP.puppet_ldapservers().sort!
  if hosts == puppet
    puts("LDAP HOSTS array is up to date with the puppet list")
  else
    puts("LDAP HOSTS array does not agree with the puppet list")
    hostsonly=hosts-puppet
    if hostsonly.length > 0
      print("In HOSTS but not in puppet:")
      puts(hostsonly)
    end
    puppetonly=puppet-hosts
    if puppetonly.length > 0
      print("In puppet but not in HOSTS: ")
      puts(puppetonly)
    end
  end
end
