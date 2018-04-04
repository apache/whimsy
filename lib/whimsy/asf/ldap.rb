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

# Note: custom ASF LDAP attributes are defined in the file:
# https://github.com/apache/infrastructure-puppet/blob/deployment/modules/ldapserver/files/asf-custom.schema

require 'wunderbar'
require 'ldap'
require 'weakref'
require 'net/http'
require 'base64'
require 'thread'
require 'securerandom'
require 'set'

module ASF
  @@weakrefs = Set.new

  module LDAP
     # see https://s.apache.org/IWu8
     # Previously derived from the following sources:
     # * https://github.com/apache/infrastructure-puppet/blob/deployment/data/common.yaml (ldapserver::slapd_peers)
     # Updated 2018-02-24
    RO_HOSTS = %w(
      ldaps://ldap-us-ro.apache.org:636
      ldaps://ldap-eu-ro.apache.org:636
    )

    RW_HOSTS = %w(
      ldaps://ldap-master.apache.org:636
    )

    # Mutex preventing simultaneous connections to LDAP from a single process
    CONNECT_LOCK = Mutex.new

    # Round robin list of LDAP hosts to be tried after failure
    HOST_QUEUE = Queue.new

    # fetch configuration from apache/infrastructure-puppet
    def self.puppet_config
      return @puppet if @puppet
      # the enclosing method is optional, so we only require the gem here
      require 'yaml'
      require_relative 'git' # just in case
      @puppet = YAML.load(ASF::Git.infra_puppet('data/common.yaml'))
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
      []
    end

    # connect to LDAP
    def self.connect(test = true, hosts = nil)
      hosts ||= self.hosts

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

    # connect to LDAP with a user and password; generally required for
    # update operations.  If a block is passed, the connection will be
    # closed after the block executes.
    #
    # when run interactively, will default user and prompt for password
    def self.bind(user=nil, password=nil, &block)
      if not user or not password
        raise ArgumentError.new('wrong number of arguments') unless STDIN.isatty

        require 'etc'
        require 'io/console'
        user ||= Etc.getlogin
        password = STDIN.getpass("Password for #{user}:")
      end

      dn = ASF::Person.new(user).dn
      raise ::LDAP::ResultError.new('Unknown user') unless dn

      ASF.ldap.unbind if ASF.ldap.bound? rescue nil
      ldap = ASF.init_ldap(true, RW_HOSTS)
      if block
        ASF.flush_weakrefs
        ldap.bind(dn, password, &block)
        ASF.init_ldap(true)
      else
        ldap.bind(dn, password)
      end
    ensure
      ASF.flush_weakrefs
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
    def self.hosts(use_config = true)
      return @hosts if @hosts # cache the hosts list
      # try whimsy config
      hosts = Array(ASF::Config.get(:ldap))

      # check system configuration
      if use_config and hosts.empty?
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
      hosts = ASF::LDAP::RO_HOSTS if hosts.empty?

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
      content[/uri (.*)\n/, 1] = hosts(false).join(' ')

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

    # modify an entry in LDAP; dump information on LDAP errors
    def self.modify(dn, list)
      ASF.ldap.modify(dn, list)
    rescue ::LDAP::ResultError
      Wunderbar.warn(list.inspect)
      Wunderbar.warn(dn.to_s)
      raise
    end

    # add an entry to LDAP; dump information on LDAP errors
    def self.add(dn, list)
      ASF.ldap.add(dn, list)
    rescue ::LDAP::ResultError
      Wunderbar.warn(list.inspect)
      Wunderbar.warn(dn.to_s)
      raise
    end

    # delete an entry from LDAP; dump information on LDAP errors
    def self.delete(dn)
      ASF.ldap.delete(dn)
    rescue ::LDAP::ResultError
      Wunderbar.warn(dn.to_s)
      raise
    end
  end

  # public entry point for establishing a connection safely
  def self.init_ldap(reset = false, hosts = nil)
    ASF::LDAP::CONNECT_LOCK.synchronize do
      @ldap = nil if reset
      @ldap ||= ASF::LDAP.connect(!reset, hosts)
    end
  end

  # Directory where ldap.conf resides.  Differs based on operating system.
  ETCLDAP = case
    when Dir.exist?('/etc/openldap') then '/etc/openldap'
    when Dir.exist?('/usr/local/etc/openldap') then '/user/local//etc/openldap'
    else '/etc/ldap'
  end

  # Returns existing LDAP connection, creating one if necessary.
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

    # keep track of which weak references are saved
    @@weakrefs << attr if object == self
  end

  def self.flush_weakrefs
    @@weakrefs.each do |attr|
      self.remove_instance_variable(attr)
    end

    @@weakrefs.clear

    # run garbage collection
    GC.start
  end

  # shortcut for dereference weakref
  def self.weakref(attr, &block)
    self.dereference_weakref(self, attr, &block)
  end

  # Obtain a list of PMC chairs from LDAP 
  # <tt>cn=pmc-chairs,ou=groups,ou=services,dc=apache,dc=org</tt>
  def self.pmc_chairs
    weakref(:pmc_chairs) {Service.find('pmc-chairs').members}
  end

  # Obtain a list of committers from LDAP 
  # <tt>cn=committers,ou=groups,dc=apache,dc=org</tt>
  def self.committers
    weakref(:committers) {Group.find('committers').members}
  end

  # Obtain a list of members from LDAP 
  # <tt>cn=member,ou=groups,dc=apache,dc=org</tt>
  # Note: includes some non-ASF member infrastructure contractors
  def self.members
    weakref(:members) {Group.find('member').members}
  end

  # Superclass for all classes which are backed by LDAP data.  Encapsulates
  # the management of collections to weak references to instance data, for
  # both performance and funcational reasons.  Sequentially finding the same
  # same object will return the same instance unless the prior instance has
  # been reclaimed by garbage collection.  This often prevents large numbers
  # of requests to fetch the same data from LDAP.
  #
  # This class also contains a number of helper classes that will construct
  # various LDAP <tt>mod</tt> objects.
  class Base
    # Simple name for the LDAP object, generally the value of <tt>uid</tt>
    # for people, and the value of <tt>cn</tt> for all of the rest.
    attr_reader :name

    # define default sort key (make Base objects sortable)
    def <=>(other)
      @name <=> other.name
    end

    # return the LDAP base for this object: identifies the subtree where
    # this object can be found.
    def self.base
      @base
    end

    # return the LDAP base for this object: identifies the subtree where
    # this object can be found.
    def base
      self.class.base
    end

    # return the collection of instances of this class, as a hash.  Note the
    # values are weak references, so may have already been reclaimed.
    def self.collection
      @collection ||= Hash.new
    end

    # Find an instance of this class, given a name
    def self.[] name
      new(name)
    end

    # Find an instance of this class, given a name
    def self.find name
      new(name)
    end

    # Create an instance of this class, given a name.  Note: if an instance
    # already exists, it will return a handle to the existing object.
    def self.new name
      begin
        object = collection[name]
        return object.reference if object and object.weakref_alive?
      rescue
      end

      super
    end

    # create an instance of this class, returning a weak reference to the
    # object for reuse.  Note: self.new will check for such a reference and
    # return it in favor of allocating a new object.
    def initialize name
      self.class.collection[name] = WeakRef.new(self)
      @name = name
    end

    # returns a reference to the underlying object.  Useful for converting
    # weak references to strong references.
    def reference
      self
    end

    # construct a weak reference to this object
    def weakref(attr, &block)
      ASF.dereference_weakref(self, attr, &block)
    end

    # Return the simple name for this LDAP object.  This is the value of
    # <tt>uid</tt> for people objects, and the value of <tt>cn</tt> for all
    # other objects.
    def id
      @name
    end

    # helper method to construct LDAP_MOD_ADD objects
    def self.mod_add(attr, vals)
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_ADD, attr.to_s, Array(vals))
    end

    # helper method to construct LDAP_MOD_REPLACE objects
    def self.mod_replace(attr, vals)
      vals = Array(vals) unless Hash === vals
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_REPLACE, attr.to_s, vals)
    end

    # helper method to construct LDAP_MOD_DELETE objects
    def self.mod_delete(attr, vals)
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_DELETE, attr.to_s, Array(vals))
    end
  end

  # a hash of attributes which is not populated until the first attempt
  # to reference a value
  class LazyHash < Hash
    # capture an initializer to be called only if necessary.
    def initialize(&initializer)
      @initializer = initializer
    end

    # if referencing a key that is not in the hash, and the initializer has
    # not yet been called, call the initializer, merge the results, and
    # try again.
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

  # Manage committers: list, add, and remove people not only from the list
  # of people, but from the list of committers.
  class Committer < Base
    @base = 'ou=role,ou=groups,dc=apache,dc=org'

    # get a list of committers
    def self.list()
      ASF.search_one(base, 'cn=committers', 'member').flatten.
        map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # create a new person and add as a new committer to LDAP.
    # Attrs must include uid, cn, and mail
    def self.create(attrs)
      # add person to LDAP
      person = ASF::Person.add(attrs)

      # add person to 'new' committers list
      ASF::LDAP.modify("cn=committers,#@base", 
        [ASF::Base.mod_add('member', [person.dn])])

      # add person to 'legacy' committers list
      ASF::Group['committers'].add(person)

      # return new person
      person
    end

    # rename a person
    def rename(newid, attrs={})
      # ensure person exists in LDAP
      raise ArgumentError(self.id) unless self.dn

      # create a new person
      new_person = ASF::Person.create(self.attrs.merge(attrs).merge(uid: newid))

      # determine what groups the individual is a member of
      uid_groups = ASF.search_subtree('dc=apache,dc=org', 
        'memberUid=#{self.id}', 'dn').flatten
      dn_groups = ASF.search_subtree('dc=apache,dc=org', 
        'member=#{self.dn}', 'dn').flatten

      # add new user to all groups
      uid_groups.each do |dn|
        ASF::LDAP.modify(dn, [ASF::Base.mod_add('memberUid', new_person.id)])
      end
      dn_groups.each do |dn|
        ASF::LDAP.modify(dn, [ASF::Base.mod_add('member', new_person.dn)])
      end

      # remove original user from all groups
      uid_groups.each do |dn|
        ASF::LDAP.modify(dn, [ASF::Base.mod_delete('memberUid', self.id)])
      end
      dn_groups.each do |dn|
        ASF::LDAP.modify(dn, [ASF::Base.mod_delete('member', self.dn)])
      end

      # remove original user
      ASF::Person.remove(person.id)

      # return new user
      new_person
    end

    # completely remove a committer from LDAP
    # ** DO NOT USE **
    # In almost all cases, use deregister instead
    def self.destroy(person)
      # if person is a string, find the person object
      person = ASF::Person.find(person) if person.instance_of? String

      # remove person from 'legacy' committers list, ignoring exceptions
      ASF::Group['committers'].remove(person) rescue nil

      # remove person from 'new' committers list, ignoring exceptions
      ASF::LDAP.modify("cn=committers,#@base", 
        [ASF::Base.mod_delete('member', [person.dn])]) rescue nil

      # remove person from LDAP (should almost never be done)
      ASF::Person.remove(person.id)
    end

    # register an existing person as a committer
    # updates both committer LDAP groups
    def self.register(person)
      if person.instance_of? String
        id = person # save for use in error message
        person = ASF::Person[person] or raise ArgumentError.new("Cannot find person: '#{id}'") 
      end

      # add person to 'new' committers list
      ASF::LDAP.modify("cn=committers,#@base", 
        [ASF::Base.mod_add('member', [person.dn])])

      # add person to 'legacy' committers list
      ASF::Group['committers'].add(person)
    end

    # deregister an existing person as a committer
    # updates both committer LDAP groups
    def self.deregister(person)
      if person.instance_of? String
        id = person # save for use in error message
        person = ASF::Person[person] or raise ArgumentError.new("Cannot find person: '#{id}'") 
      end

      # remove person from 'legacy' committers list
      ASF::Group['committers'].remove(person)

      # remove person from 'new' committers list
      ASF::LDAP.modify("cn=committers,#@base", 
        [ASF::Base.mod_delete('member', [person.dn])])
    end

  end

  class Person < Base
    @base = 'ou=people,dc=apache,dc=org'

    def self.group_base
      'ou=people,' + ASF::Group.base
    end

    # Obtain a list of people known to LDAP.  LDAP filters may be used
    # to retrieve only a subset.
    def self.list(filter='uid=*')
      ASF.search_one(base, filter, 'uid').flatten.map {|uid| find(uid)}
    end

    # pre-fetch a given set of attributes, for a given list of people
    def self.preload(attributes, people=[])
      list = Hash.new {|hash, name| hash[name] = find(name)}

      attributes = [attributes].flatten

      if people.empty? or people.length > 1000
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
    def self.[] id
      person = super
      person.attrs['dn'] ? person : nil
    end

    # list of LDAP attributes for this person, populated lazily upon
    # first reference.
    def attrs
      @attrs ||= LazyHash.new {ASF.search_one(base, "uid=#{name}").first}
    end

    # reload all attributes from LDAP
    def reload!
      @attrs = nil
      attrs
    end

    # Is this person listed in the committers LDAP group?
    def asf_committer?
       ASF::Group.new('committers').include? self
    end

    # determine if the person is banned.  If scanning a large list, consider
    # preloading the <tt>loginShell</tt> attributes for these people.
    def banned?
      # FreeBSD uses /usr/bin/false; Ubuntu uses /bin/false
      not attrs['loginShell'] or %w(/bin/false bin/nologin bin/no-cla).any? {|a| attrs['loginShell'].first.include? a}
    end

    # determine if the person has no login.  If scanning a large list, consider
    # preloading the <tt>loginShell</tt> attributes for these people.
    def nologin?
      # FreeBSD uses /usr/bin/false; Ubuntu uses /bin/false
      not attrs['loginShell'] or %w(/bin/false bin/nologin bin/no-cla).any? {|a| attrs['loginShell'].first.include? a}
    end

    # determine if the person has asf-banned: yes.  If scanning a large list, consider
    # preloading the <tt>asf-banned</tt> attributes for these people.
    def asf_banned?
      # No idea what this means (yet)
      attrs['asf-banned'] == 'yes'
    end

    # primary mail addresses
    def mail
      attrs['mail'] || []
    end

    # list all of the alternative emails for this person
    def alt_email
      attrs['asf-altEmail'] || []
    end

    # list all of the PGP key fingerprints
    def pgp_key_fingerprints
      attrs['asf-pgpKeyFingerprint'] || []
    end

    # list all of the ssh public keys
    def ssh_public_keys
      attrs['sshPublicKey'] || []
    end

    # list all of the personal URLs
    def urls
      attrs['asf-personalURL'] || []
    end

    # list of LDAP committees that this individual is a member of
    def committees
      # legacy LDAP entries
      committees = weakref(:committees) do
        Committee.list("member=uid=#{name},#{base}")
      end

      # add in projects (currently only includes GUINEAPIGS)
      # Get list of project names where the person is an owner
      projects = self.projects.select{|prj| prj.owners.include? self}.map(&:name)
      committees += ASF::Committee.pmcs.select do |pmc| 
        projects.include? pmc.name
      end

      # dedup
      committees.uniq
    end

    # list of LDAP projects that this individual is a member of
    def projects
      weakref(:projects) do
        Project.list("member=uid=#{name},#{base}")
      end
    end

    # list of LDAP groups that this individual is a member of
    def groups
      weakref(:groups) do
        Group.list("memberUid=#{name}")
      end
    end

    # list of LDAP services that this individual is a member of
    def services
      weakref(:services) do
        Service.list("member=#{dn}")
      end
    end

    # Designated Name from LDAP
    def dn
      "uid=#{name},#{ASF::Person.base}"
    end

    # Allow artibtrary LDAP attibutes to be referenced as object properties.
    # Example: <tt>ASF::Person.find('rubys').cn</tt>.  Can also be used
    # to modify an LDAP attribute.
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

    # update an LDAP attribute for this person.  This needs to be run
    # either inside or after ASF::LDAP.bind.
    def modify(attr, value)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_replace(attr.to_s, value)])
      attrs[attr.to_s] = value
    end

    # add a new person to LDAP.  Attrs must include uid, cn, and mail
    def self.add(attrs)
      # convert keys to strings
      attrs = attrs.map {|key, value| [key.to_s, value]}.to_h

      # verify required arguments are present
      %w(uid cn mail).each do |required|
        unless attrs.include? required
          raise ArgumentError.new("missing attribute #{required}")
        end
      end

      availid = attrs['uid']

      # determine next uid and group, unless provided
      nextuid = attrs['uidNumber'] || 
        ASF::search_one(ASF::Person.base, 'uid=*', 'uidNumber').
          flatten.map(&:to_i).max + 1

      nextgid = attrs['gidNumber']
      unless nextgid
        nextgid = ASF::search_one(group_base, 'cn=*', 'gidNumber').
          flatten.map(&:to_i).max + 1

        # create new LDAP group
        entry = [
          mod_add('objectClass', ['posixGroup', 'top']),
          mod_add('cn', availid),
          mod_add('userPassword', '{crypt}*'),
          mod_add('gidNumber', nextgid.to_s),
        ]
      end
 
      # fixed attributes
      attrs.merge!({
        'uidNumber' => nextuid.to_s,
        'gidNumber' => nextuid.to_s,
        'asf-committer-email' => "#{availid}@apache.org",
        'objectClass' => %w(person top posixAccount organizationalPerson
           inetOrgPerson asf-committer hostObject ldapPublicKey)
      })

      # defaults
      attrs['loginShell'] ||= '/usr/local/bin/bash'
      attrs['homeDirectory'] ||= "/home/#{availid}"
      attrs['host'] ||= "home.apache.org"
      attrs['asf-sascore'] ||= "10"

      # parse name
      attrs = ASF::Person.ldap_name(attrs['cn']).merge(attrs)

      # generate a password that is between 8 and 16 alphanumeric characters
      if not attrs['userPassword']
        while attrs['userPassword'].to_s.length < 8
          attrs['userPassword'] = SecureRandom.base64(12).gsub(/\W+/, '')
        end
      end

      ASF::LDAP.add("cn=#{availid},#{group_base}", entry)

      # create new LDAP person
      begin
        entry = attrs.map {|key, value| mod_add(key, value)}
        ASF::LDAP.add("uid=#{availid},#{base}", entry)
      rescue
        # don't leave an orphan group behind
        ASF::LDAP.delete("cn=#{availid},#{group_base}") rescue nil
        raise
      end

      # return person object with password filled in
      person = ASF::Person.find(availid)
      person.attrs['userPassword'] = [attrs['userPassword']]
      person
    end

    # remove a person from LDAP
    def self.remove(availid)
      ASF::LDAP.delete("cn=#{availid},#{group_base}")
      ASF::LDAP.delete("uid=#{availid},#{base}")
    end
  end

  #
  # Access to LDAP groups; where committer lists for PMCs have traditionally
  # been stored.  The intent is to move this data to member attributes on
  # Project lists.
  #
  class Group < Base
    @base = 'ou=groups,dc=apache,dc=org'

    # obtain a list of groups from LDAP
    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| find(cn)}
    end

    # determine if a given ASF::Person is a member of this group
    def include?(person)
      filter = "(&(cn=#{name})(memberUid=#{person.name}))"
      if ASF.search_one(base, filter, 'cn').empty?
        return false
      else
        return true
      end
    end

    # fetch <tt>dn</tt>, <tt>member</tt>, <tt>modifyTimestamp</tt>, and
    # <tt>createTimestamp</tt> for all groups in LDAP.
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

    # Date this committee was last modified in LDAP.
    attr_accessor :modifyTimestamp

    # Date this committee was initially created in LDAP.
    attr_accessor :createTimestamp

    # return group only if it actually exits
    def self.[] name
      group = super
      group.members.empty? ? nil : group
    end

    # setter for members, should only be used by #preload
    def members=(members)
      @members = WeakRef.new(members)
    end

    # return a list of ASF::People who are memers of this group
    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'memberUid').flatten
      end

      members.map {|uid| Person.find(uid)}
    end

    # Designated Name from LDAP
    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first
    end

    # remove people from an existing group in LDAP
    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:id)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('memberUid', people)])
    ensure
      @members = nil
    end

    # add people to an existing group in LDAP
    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:id)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('memberUid', people)])
    ensure
      @members = nil
    end

    # add a new group to LDAP
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

    # remove a group from LDAP
    def self.remove(name)
      ASF::LDAP.delete("cn=#{name},#{base}")
    end
  end

  # Ultimately, this will include both PMCs and PPMCs, and enable separate
  # updating of owners and members.  For now this is only used for PPMCs
  # and owners and members are kept in sync.
  class Project < Base
    @base = 'ou=project,ou=groups,dc=apache,dc=org'

    # obtain a list of projects from LDAP
    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| Project.find(cn)}
    end

    # return project only if it actually exits
    def self.[] name
      project = super
      project.members.empty? ? nil : project
    end

    # fetch <tt>dn</tt>, <tt>member</tt>, <tt>modifyTimestamp</tt>, and
    # <tt>createTimestamp</tt> for all projects in LDAP.
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

    # Date this committee was last modified in LDAP.
    attr_accessor :modifyTimestamp

    # Date this committee was initially created in LDAP.
    attr_accessor :createTimestamp

    # Designated Name from LDAP
    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first rescue nil
    end

    # create an LDAP group for this project
    def create(owners, committers=nil)
      committers = Array(committers || owners).map(&:dn)
      owners = Array(owners).map(&:dn)

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

    # setter for members, should only be called by #preload.
    def members=(members)
      @members = WeakRef.new(members)
    end

    # setter for owners, should only be called by #preload.
    def owners=(owners)
      @owners = WeakRef.new(owners)
    end

    # list of committers on this project.  Stored in LDAP as a <tt>member</tt>
    # attribute.
    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # list of owners on this project.  Stored in LDAP as a <tt>owners</tt>
    # attribute.
    def owners
      owners = weakref(:owners) do
        ASF.search_one(base, "cn=#{name}", 'owner').flatten
      end

      owners.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # remove people from a project as owners and members in LDAP
    def remove(people)
      remove_owners(people)
      remove_members(people)
    end

    # remove people as owners of a project in LDAP
    def remove_owners(people)
      @owners = nil
      removals = (Array(people) & owners).map(&:dn)
      unless removals.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('owner', removals)])
      end
    ensure
      @owners = nil
    end

    # remove people as members of a project in LDAP
    def remove_members(people)
      @members = nil
      removals = (Array(people) & members).map(&:dn)
      unless removals.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', removals)])
      end
    ensure
      @members = nil
    end

    # add people to a project as members and owners in LDAP
    def add(people)
      add_owners(people)
      add_members(people)
    end

    # add people as owners of a project in LDAP
    def add_owners(people)
      @owners = nil
      additions = (Array(people) - owners).map(&:dn)
      unless additions.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('owner', additions)])
      end
    ensure
      @owners = nil
    end

    # add people as members of a project in LDAP
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

    # return a list of committees, from LDAP.
    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten.map {|cn| Committee.find(cn)}
    end

    # fetch <tt>dn</tt>, <tt>member</tt>, <tt>modifyTimestamp</tt>, and
    # <tt>createTimestamp</tt> for all committees in LDAP.
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

    # Date this committee was last modified in LDAP.
    attr_accessor :modifyTimestamp

    # Date this committee was initially created in LDAP.
    attr_accessor :createTimestamp

    # return committee only if it actually exits
    def self.[] name
      committee = super
      return committee if GUINEAPIGS.include? name
      committee.members.empty? ? nil : committee
    end

    # setter for members attribute, should only be used by 
    # ASF::Committee.preload
    def members=(members)
      @members = WeakRef.new(members)
    end

    # DEPRECATED.  List of members for this committee.  Use owners as it
    # is less ambiguous.
    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # temp list of projects that have moved over to new project LDAP schema
    GUINEAPIGS = %w(incubator whimsy jmeter axis mynewt atlas accumulo
      madlib streams fluo impala)

    # List of owners for this committee, i.e. people who are members of the
    # committee and have update access.  Data is obtained from LDAP.
    def owners
      if GUINEAPIGS.include? name
        ASF::Project.find(name).owners
      else
        members
      end
    end

    # List of committers for this committee.  Data is obtained from LDAP.  This
    # data is generally stored in an attribute named <tt>member</tt>.
    def committers
      if GUINEAPIGS.include? name
        ASF::Project.find(name).members
      else
        ASF::Group.find(name).members
      end
    end

    # remove people as owners of a project in LDAP
    def remove_owners(people)
      if GUINEAPIGS.include? name
        ASF::Project.find(name).remove_owners(people)
      else
        project = ASF::Project[name]
        project.remove_owners(people) if project
        remove(people)
      end
    end

    # remove people as members of a project in LDAP
    def remove_committers(people)
      if GUINEAPIGS.include? name
        ASF::Project.find(name).remove_members(people)
      else
        project = ASF::Project[name]
        project.remove_members(people) if project
        ASF::Group.find(name).remove(people)
      end
    end

    # add people as owners of a project in LDAP
    def add_owners(people)
      if GUINEAPIGS.include? name
        ASF::Project.find(name).add_owners(people)
      else
        project = ASF::Project[name]
        project.add_owners(people) if project
        add(people)
      end
    end

    # add people as committers of a project.  This information is stored
    # in LDAP using a <tt>members</tt> attribute.
    def add_committers(people)
      if GUINEAPIGS.include? name
        ASF::Project.find(name).add_members(people)
      else
        project = ASF::Project[name]
        project.add_members(people) if project
        ASF::Group.find(name).add(people)
      end
    end

    # Designated Name from LDAP
    def dn
      if GUINEAPIGS.include? name
        @dn ||= ASF::Project.find(name).dn
      else
        @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first rescue nil
      end
    end

    # DEPRECATED remove people from a committee.  Call #remove_owners instead.
    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:dn)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', people)])
    ensure
      @members = nil
    end

    # DEPRECATED.  add people to a committee.  Call #add_owners instead.
    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:dn)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', people)])
    ensure
      @members = nil
    end

    # add a new committee to LDAP
    def self.add(name, people)
      entry = [
        mod_add('objectClass', ['groupOfNames', 'top']),
        mod_add('cn', name),
        mod_add('member', Array(people).map(&:dn))
      ]

      ASF::LDAP.add("cn=#{name},#{base}", entry)
    end

    # remove a committee from LDAP
    def self.remove(name)
      ASF::LDAP.delete("cn=#{name},#{base}")
    end
  end

  #
  # Access to LDAP services (<tt>ou=groups,ou=services,dc=apache,dc=org</tt>)
  #
  class Service < Base
    @base = 'ou=groups,ou=services,dc=apache,dc=org'

    # return a list of services, from LDAP.
    def self.list(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten
    end

    # Designated Name from LDAP
    def dn
      return @dn if @dn
      dns = ASF.search_subtree(self.class.base, "cn=#{name}", 'dn')
      @dn = dns.first.first unless dns.empty?
      @dn
    end

    # base subtree for this service
    def base
      if dn
        dn.sub(/^cn=.*?,/, '')
      else
        super
      end
    end

    # fetch <tt>dn</tt>, <tt>member</tt>, <tt>modifyTimestamp</tt>, and
    # <tt>createTimestamp</tt> for all services in LDAP.
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

    # Date this committee was last modified in LDAP.
    attr_accessor :modifyTimestamp

    # Date this committee was initially created in LDAP.
    attr_accessor :createTimestamp

    # setters for members.  Should only be called by #preload
    def members=(members)
      @members = WeakRef.new(members)
    end

    # list of members for this service in LDAP
    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/,1]}
    end

    # remove people from this service in LDAP
    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:dn)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', people)])
    ensure
      @members = nil
    end

    # add people to this service in LDAP
    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:dn)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', people)])
    ensure
      @members = nil
    end
  end

  # <tt>ou=apps</tt> subtree of <tt>ou=groups,dc=apache,dc=org</tt>, currently
  # only used for <tt>hudson-jobadmin</tt>
  class AppGroup < Service
    @base = 'ou=apps,ou=groups,dc=apache,dc=org'

    def self.list(filter='cn=*')
      ASF.search_subtree(base, filter, 'cn').flatten.map {|cn| find(cn)}
    end

    # remove people from an application group.
    def remove(people)
      @members = nil
      people = (Array(people) & members).map(&:dn)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', people)])
    ensure
      @members = nil
    end

    # add people to an application group.
    def add(people)
      @members = nil
      people = (Array(people) - members).map(&:dn)
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', people)])
    ensure
      @members = nil
    end
  end

  # <tt>ou=auth</tt> subtree of <tt>ou=groups,dc=apache,dc=org</tt>, used for
  # subprojects and a variety of organizational constructs (accounting,
  # exec-officers, fundraising, trademarks, ...)
  class AuthGroup < Service
    @base = 'ou=auth,ou=groups,dc=apache,dc=org'
  end
end

if __FILE__ == $0
  module ASF
    module LDAP
      def self.getHOSTS # :nodoc:
        RO_HOSTS
      end
    end
  end
  hosts=ASF::LDAP.getHOSTS().sort
  puppet=ASF::LDAP.puppet_ldapservers().sort
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
