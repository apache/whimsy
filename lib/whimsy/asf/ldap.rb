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
require 'securerandom'
require 'set'

module ASF
  @@weakrefs = Set.new

  module LDAP
    # Mutex preventing simultaneous connections to LDAP from a single process
    CONNECT_LOCK = Mutex.new

    # connect to LDAP
    def self.connect(test = true, hosts = nil)
      # If the host list is specified, use that as is
      # otherwise ensure we start with the next in the default list
      hosts ||= self.hosts.rotate!

      # Try each host at most once
      hosts.each do |host|

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
        raise ArgumentError.new('Need user name and password') unless STDIN.isatty

        require 'etc'
        require 'io/console'
        user ||= Etc.getlogin
        password = STDIN.getpass("Password for #{user}:")
      end

      dn = ASF::Person.new(user).dn
      raise ::LDAP::ResultError.new('Unknown user') unless dn

      ASF.ldap.unbind if ASF.ldap.bound? rescue nil
      ldap = ASF.init_ldap(true, self.rwhosts)
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

    # allow override of writable host by :ldaprw
    def self.rwhosts
      return @rwhosts if @rwhosts # cache the rwhosts list
      rwhosts = Array(ASF::Config.get(:ldaprw)) # allow separate override for RW LDAP
      rwhosts = hosts if rwhosts.empty? # default to RO hosts
      raise 'Cannot determine writable LDAP URI from ldap.conf or local config!' if rwhosts.empty?
      @rwhosts = rwhosts
    end

    # determine what LDAP hosts are available
    # use_config=false is needed for the configure method only
    def self.hosts(use_config = true)
      return @hosts if @hosts # cache the hosts list
      # try whimsy config (overrides ldap.conf)
      hosts = Array(ASF::Config.get(:ldap))

      # check system configuration
      if use_config and hosts.empty?
        conf = "#{ETCLDAP}/ldap.conf"
        if File.exist? conf
          uris = File.read(conf)[/^uri\s+(.*)/i, 1].to_s
          hosts = uris.scan(%r{ldaps?://\S+}) # May not have a port
          Wunderbar.debug "Using hosts from LDAP config"
        end
      else
        Wunderbar.debug "Using hosts from Whimsy config"
      end

      # There is no default
      raise 'Cannot determine LDAP URI from ldap.conf or local config!' if hosts.empty?

      hosts.shuffle!
      # Wunderbar.debug "Hosts:\n#{hosts.join(' ')}"
      @hosts = hosts
    end

    # query and extract cert from openssl output
    # returns the last certificate found (WHIMSY-368)
    def self.extract_cert(host=nil)
      host ||= hosts.sample[%r{//(.*?)(/|$)}, 1]
      host += ':636' unless host =~ %r{:\d+\z}
      cmd = ['openssl', 's_client', '-connect', host, '-showcerts'] 
      puts cmd.join(' ')
      out, _, _ = Open3.capture3(*cmd)
      out.scan(/^-+BEGIN.*?\n-+END[^\n]+\n/m).last
    end

    # update /etc/ldap.conf. Usage:
    #
    #   sudo ruby -I /srv/whimsy/lib -r whimsy/asf -e "ASF::LDAP.configure"
    #
    def self.configure
      cert = Dir["#{ETCLDAP}/asf*-ldap-client.pem"].first

      # verify/obtain/write the cert
      unless cert
        cert = "#{ETCLDAP}/asf-ldap-client.pem"
        File.write cert, self.extract_cert
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

    # determine if ldap has been configured at least once
    def self.configured?
      return File.read("#{ETCLDAP}/ldap.conf").include? "asf-ldap-client.pem"
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
    when Dir.exist?('/usr/local/etc/openldap') then '/user/local/etc/openldap'
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
      [attrs].flatten.join(' ')

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

    result.map! {|hash| hash[attrs]} if attrs.is_a? String

    result.compact
  end

  # safely dereference a weakref array attribute.  Block provided is
  # used when reference is not set or has been reclaimed.
  # N.B. dereference_weakref(object, :XYZ, block) stores the reference in @XYZ
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
  # N.B. weakref(:XYZ) stores the reference in @XYZ
  def self.weakref(attr, &block)
    self.dereference_weakref(self, attr, &block)
  end

  # Obtain a list of PMC chairs from LDAP
  # <tt>cn=pmc-chairs,ou=groups,ou=services,dc=apache,dc=org</tt>
  # Note: this list may include non-PMC VPs.
  def self.pmc_chairs
    weakref(:pmc_chairs) {Service.find('pmc-chairs').members}
  end

  # Obtain a list of committers from LDAP
  # <tt>cn=committers,ou=role,ou=groups,dc=apache,dc=org</tt>
  def self.committers
    weakref(:committers) {RoleGroup.find('committers').members}
  end

  # Obtain a list of committerids from LDAP
  # <tt>cn=committers,ou=role,ou=groups,dc=apache,dc=org</tt>
  def self.committerids
    weakref(:committerids) {RoleGroup.find('committers').memberids}
  end

  # Obtain a list of members from LDAP
  # <tt>cn=member,ou=groups,dc=apache,dc=org</tt>
  # Note: includes some non-ASF member infrastructure contractors
  # TODO: convert to RoleGroup at some point?
  def self.members
    weakref(:members) {Group.find('member').members}
  end

  # Obtain a list of memberids from LDAP
  # <tt>cn=member,ou=groups,dc=apache,dc=org</tt>
  # Note: includes some non-ASF member infrastructure contractors
  # TODO: convert to RoleGroup at some point?
  def self.memberids
    weakref(:memberids) {Group.find('member').memberids}
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
      @collection ||= {}
    end

    # Find an instance of this class, given a name
    def self.[](name)
      new(name)
    end

    # Find an instance of this class, given a name
    def self.find(name)
      new(name)
    end

    # Create an instance of this class, given a name.  Note: if an instance
    # already exists, it will return a handle to the existing object.
    def self.new(name)
      begin
        object = collection[name]
        return object.reference if object&.weakref_alive?
      rescue
      end

      super
    end

    # create an instance of this class, returning a weak reference to the
    # object for reuse.  Note: self.new will check for such a reference and
    # return it in favor of allocating a new object.
    def initialize(name)
      self.class.collection[name] = WeakRef.new(self)
      @name = name
    end

    # returns a reference to the underlying object.  Useful for converting
    # weak references to strong references.
    def reference
      self
    end

    # construct a weak reference to this object
    # N.B. weakref(:XYZ) stores the reference in @XYZ
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
      vals = Array(vals) unless vals.is_a? Hash
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_REPLACE, attr.to_s, vals)
    end

    # helper method to construct LDAP_MOD_DELETE objects
    def self.mod_delete(attr, vals)
      ::LDAP::Mod.new(::LDAP::LDAP_MOD_DELETE, attr.to_s, Array(vals))
    end

    def hasLDAP?
      ASF.search_one(base, "cn=#{name}", 'cn').any?
    end

  end

  # a hash of attributes which is not populated until the first attempt
  # to reference a value
  class LazyHash < Hash
    # capture an initializer to be called only if necessary.
    def initialize(&initializer)
      super() {}
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
    def self.list
      ASF.search_one(base, 'cn=committers', 'member').flatten.
        map {|uid| Person.find uid[/uid=(.*?),/, 1]}
    end

    # get a list of committers (ids only)
    def self.listids
      ASF.search_one(base, 'cn=committers', 'member').flatten.
        map {|uid| uid[/uid=(.*?),/, 1]}
    end

    # create a new person and add as a new committer to LDAP.
    # Attrs must include uid, cn, and mail
    def self.create(attrs)
      # add person to LDAP
      person = ASF::Person.add(attrs)

      # add person to committers lists
      register(person)

      # return new person
      person
    end

    # rename a person/committer
    def rename(newid, attrs={})
      # ensure person exists in LDAP
      raise ArgumentError(self.id) unless self.dn

      # create a new person/committer (this should create new uid/gid numbers, if not overridden)
      new_person = ASF::Committer.create(self.attrs.merge(attrs).merge(uid: newid))

      # determine what groups the individual is a member of
      uid_groups = ASF.search_subtree('dc=apache,dc=org',
        "memberUid=#{self.id}", 'dn').flatten
      dn_groups = ASF.search_subtree('dc=apache,dc=org',
        "member=#{self.dn}", 'dn').flatten

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
      # TODO: the old entry should probably be disabled instead, to avoid reuse of uid/gid
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
      ASF::LDAP.modify("cn=committers,#{@base}",
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
      ASF::LDAP.modify("cn=committers,#{@base}",
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
      ASF::LDAP.modify("cn=committers,#{@base}",
        [ASF::Base.mod_delete('member', [person.dn])])
    end

  end

  class Person < Base
    @base = 'ou=people,dc=apache,dc=org'

    # Obtain a list of people known to LDAP.  LDAP filters may be used
    # to retrieve only a subset.
    def self.list(filter='uid=*', attributes='uid')
      ASF.search_one(base, filter, attributes).flatten.map {|uid| find(uid)}
    end

    # Obtain a list of people (ids) known to LDAP.  LDAP filters may be used
    # to retrieve only a subset. Result is returned as a list of ids only.
    def self.listids(filter='uid=*')
      ASF.search_one(base, filter, 'uid').flatten
    end

    # Get a list of ids matching a name
    # matches against 'cn', also 'givenName' and 'sn' if the former does not match
    # returns an array of ids; may be empty
    # Intended for use when matching a few people individually.
    def self.find_by_name(name)
      res = listids("(cn=#{name})")
      if res.empty?
        parts = name.split(' ')
        res = listids("(&(givenName=#{parts[0]})(sn=#{parts[-1]}))")
      end
      res
    end

    # Get id matching a name, or nil
    # matches against 'cn', also 'givenName' and 'sn' if the former does not match
    # returns a single id, or nil if there is not a unique match
    # Intended for use when matching a few people individually.
    def self.find_by_name!(name)
      res = find_by_name(name)
      return nil unless res.size == 1
      res.first
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

      zero = Hash[attributes.map {|attribute| [attribute, nil]}]

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
    def self.[](id)
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
      attrs['asf-banned']&.first == 'yes'
    end

    # is the login marked as inactive?
    def inactive?
      nologin? || asf_banned?
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
    # TODO should this be deleted?
    # It seems to be used partly as LDAP membership and partly as PMC membership (which were originally generally the same)
    # If the former, then it disappears.
    # If the latter, then it needs to be derived from project_owners filtered to keep only PMCs
    def committees
      # legacy LDAP entries
      committees = []
#      committees = weakref(:committees) do
#        Committee.list("member=uid=#{name},#{base}")
#      end

      # add in projects
      # Get list of project names where the person is an owner
      projects = self.projects.select {|prj| prj.owners.include? self}.map(&:name)
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

    # list of LDAP projects that this individual is an owner of - i.e. on (P)PMC
    def project_owners
      weakref(:project_owners) do
        Project.list("owner=uid=#{name},#{base}")
      end
    end

    # list of Podlings that this individual is a member (owner) of
    def podlings
      ASF::Podling.current.select {|pod| project_owners.map(&:name).include? pod.name}
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
        Service.listcns("member=#{dn}")
      end
    end

    # Designated Name from LDAP
    def dn
      "uid=#{name},#{ASF::Person.base}"
    end

    # Allow arbitrary LDAP attributes to be referenced as object properties.
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
          value = value.dup.force_encoding('utf-8') if value.is_a? String
          value
        end

        if result.length == 1
          result.first
        else
          result
        end
      end
    end

    # is argument an empty string on its own or in a singleton array?
    def arg_empty?(arg)
      return arg.empty? || (arg.is_a?(Array) && arg.size == 1 && arg.first.empty?)
    end

    # update an LDAP attribute for this person.  This needs to be run
    # either inside or after ASF::LDAP.bind.
    def modify(attr, value)
      # OK to remove the attribute? Only support givenName for now...
      if attr == 'givenName' and arg_empty?(value)
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete(attr.to_s, nil)])
        attrs.delete(attr.to_s) # remove the cached entry
      else
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_replace(attr.to_s, value)])
        # attributes are expected to be arrays
        attrs[attr.to_s] = value.is_a?(String) ? [value] : value
      end
    end

    MINIMUM_USER_UID = 6000 # from asfpy/ldap
    # Return the next free value for use as uidNumber/gidNumber
    # Optionally return several free values as an array
    def self.next_uidNumber(count=1)
      raise ArgumentError.new "Count: #{count} is less than 1!" if count < 1
      numbers = ASF::search_one(ASF::Person.base, 'uid=*', ['uidNumber', 'gidNumber']).
        map{|i| u=i['uidNumber'];g=i['gidNumber']; u == g ? u : [u,g]}.flatten.map(&:to_i).
        select{|i| i >= MINIMUM_USER_UID}.uniq.sort.lazy
      enum = Enumerator.new do |output|
        last = MINIMUM_USER_UID - 1 # in case no valid entries exist
        loop do
            curr = numbers.next
            if curr <= last + 1
              last = curr
            else
                (last+1..curr-1).each {|i| output << i}
                last = curr
            end
        end
        # in case we ran off the end...
        loop do
          last = last+1
          output << last
        end
      end
      if (count == 1)
        enum.first
      else
        enum.take(count)
      end
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
      nextuid = attrs['uidNumber']
      if nextuid
        raise ArgumentError.new("gidNumber #{gidNumber} != uidNumber #{uidNumber}") unless attrs['gidNumber'] == nextuid
      else
        nextuid = next_uidNumber
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
      attrs['loginShell'] ||= '/bin/bash' # as per asfpy.ldap
      attrs['homeDirectory'] ||= File.join("/home", availid)
      attrs['host'] ||= "home.apache.org"
      attrs['asf-sascore'] ||= "10"

      # parse name if sn has not been provided (givenName is optional)
      attrs = ASF::Person.ldap_name(attrs['cn']).merge(attrs) unless attrs['sn']

      # user is expected to use id.apache.org to set their initial password
      attrs['userPassword'] = '{CRYPT}*' # invalid password (I assume)

      # create new LDAP person
      entry = attrs.map {|key, value| mod_add(key, value)}
      ASF::LDAP.add("uid=#{availid},#{base}", entry)

      # return person object; they must use id.apache.org to reset the password
      person = ASF::Person.find(availid)
      person
    end

    # remove a person from LDAP
    def self.remove(availid)
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
        members = results['memberUid'] || []
        group.members = members
        [group, members]
      end]
    end

    # Date this committee was last modified in LDAP.
    attr_accessor :modifyTimestamp

    # Date this committee was initially created in LDAP.
    attr_accessor :createTimestamp

    # return group only if it actually exits
    def self.[](name)
      group = super
      group.dn ? group : nil
    end

    # setter for members, should only be used by #preload
    # N.B. Do not dereference @members directly; use weakref(:members) instead
    def members=(members)
      @members = WeakRef.new(members)
    end

    # return a list of ASF::People who are members of this group
    def members
      memberids.map {|uid| Person.find(uid)}
    end

    # return a list of ids who are members of this group
    def memberids
      weakref(:members) do # initialises @members if necessary
        ASF.search_one(base, "cn=#{name}", 'memberUid').flatten
      end
    end

    # Designated Name from LDAP
    def dn
      @dn ||= ASF.search_one(base, "cn=#{name}", 'dn').first.first rescue nil
    end

    # remove people from an existing group in LDAP
    def remove(people)
      @members = nil  # force fresh LDAP search
      people = (Array(people) & members).map(&:id)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('memberUid', people)])
    ensure
      @members = nil
    end

    # add people to an existing group in LDAP
    def add(people)
      @members = nil  # force fresh LDAP search
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

    # obtain a list of projectids from LDAP
    def self.listids(filter='cn=*')
      ASF.search_one(base, filter, 'cn').flatten
    end

    # return project only if it actually exits
    def self.[](name)
      project = super
      project.dn ? project : nil
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
        # TODO members and owners are duplicated in the project object and the returned hash
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
    # N.B. Do not dereference @members directly; use weakref(:members) instead
    def members=(members)
      @members = WeakRef.new(members)
    end

    # setter for owners, should only be called by #preload.
    # N.B. Do not dereference @owners directly; use weakref(:owners) instead
    def owners=(owners)
      @owners = WeakRef.new(owners)
    end

    # list of committers on this project.  Stored in LDAP as a <tt>member</tt>
    # attribute.
    def members
      memberids.map {|id| Person.find id}
    end

    # list of member ids in the project
    def memberids
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end
      members.map {|uid| uid[/uid=(.*?),/, 1]}
    end

    # list of owners on this project.  Stored in LDAP as a <tt>owners</tt>
    # attribute.
    def owners
      ownerids.map {|id| Person.find id}
    end

    # list of owner ids in the project
    def ownerids
      owners = weakref(:owners) do
        ASF.search_one(base, "cn=#{name}", 'owner').flatten
      end
      owners.map {|uid| uid[/uid=(.*?),/, 1]}
    end

    # remove people from a project as owners and members in LDAP
    def remove(people)
      remove_owners(people)
      remove_members(people)
    end

    # remove people as owners of a project in LDAP
    def remove_owners(people)
      @owners = nil  # force fresh LDAP search
      removals = (Array(people) & owners).map(&:dn)
      unless removals.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('owner', removals)])
      end
    ensure
      @owners = nil
    end

    # remove people as members of a project in LDAP
    def remove_members(people)
      @members = nil  # force fresh LDAP search
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
      @owners = nil  # force fresh LDAP search
      additions = (Array(people) - owners).map(&:dn)
      unless additions.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('owner', additions)])
      end
    ensure
      @owners = nil
    end

    # add people as members of a project in LDAP
    def add_members(people)
      @members = nil  # force fresh LDAP search
      additions = (Array(people) - members).map(&:dn)
      unless additions.empty?
        ASF::LDAP.modify(self.dn, [ASF::Base.mod_add('member', additions)])
      end
    ensure
      @members = nil
    end
  end

  # representation of Committee, i.e. entry in committee-info.txt
  # includes PMCs and other committees, but does not include podlings
  class Committee < Base
    @base = nil # not sure it makes sense to define base here

    # return committee only if it actually exists
    def self.[](name)
      committee = super
      # Cannot rely on presence/absence of LDAP record as projects includes podlings
      (ASF::Committee.pmcs + ASF::Committee.nonpmcs).map(&:name).include?(name) ? committee : nil
    end

    # Date this committee was last modified in LDAP.
    # defer to Project; must have called project.preload
    def modifyTimestamp
      ASF::Project[name].modifyTimestamp
    end

    # Date this committee was initially created in LDAP.
    # defer to Project; must have called project.preload
    def createTimestamp
      ASF::Project[name].createTimestamp
    end

    # List of owners for this committee, i.e. people who are members of the
    # committee and have update access.  Data is obtained from LDAP.
    # Takes info from Project
    def owners
      ASF::Project.find(name).owners
    end

    # List of owner ids for this committee
    # Takes info from Project
    def ownerids
      ASF::Project.find(name).ownerids
    end

    # List of committers for this committee.  Data is obtained from LDAP.  This
    # data is generally stored in an attribute named <tt>member</tt>.
    # Takes info from Project
    def committers
      ASF::Project.find(name).members
    end

    # List of committer ids for this committee
    # Takes info from Project
    def committerids
      ASF::Project.find(name).memberids
    end

    # remove people as owners of a project in LDAP
    def remove_owners(people)
      ASF::Project.find(name).remove_owners(people)
    end

    # remove people as members of a project in LDAP
    def remove_committers(people)
      ASF::Project.find(name).remove_members(people)
    end

    # add people as owners of a project in LDAP
    def add_owners(people)
      ASF::Project.find(name).add_owners(people)
    end

    # add people as committers of a project.  This information is stored
    # in LDAP using a <tt>members</tt> attribute.
    def add_committers(people)
      ASF::Project.find(name).add_members(people)
    end

    # Designated Name from LDAP
    def dn
      @dn ||= ASF::Project.find(name).dn
    end

  end

  #
  # Access to LDAP services (<tt>ou=groups,ou=services,dc=apache,dc=org</tt>)
  #
  class Service < Base
    @base = 'ou=groups,ou=services,dc=apache,dc=org'

    # return a list of services (cns only), from LDAP.
    def self.listcns(filter='cn=*')
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
    # N.B. Do not dereference @members directly; use weakref(:members) instead
    def members=(members)
      @members = WeakRef.new(members)
    end

    # list of members for this service in LDAP
    def members
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| Person.find uid[/uid=(.*?),/, 1]}
    end

    # list of memberids for this service in LDAP
    def memberids
      members = weakref(:members) do
        ASF.search_one(base, "cn=#{name}", 'member').flatten
      end

      members.map {|uid| uid[/uid=(.*?),/, 1]}
    end

    # remove people from this service in LDAP
    def remove(people)
      @members = nil # force fresh LDAP search
      people = (Array(people) & members).map(&:dn)
      return if people.empty?
      ASF::LDAP.modify(self.dn, [ASF::Base.mod_delete('member', people)])
    ensure
      @members = nil
    end

    # add people to this service in LDAP
    def add(people)
      @members = nil # force fresh LDAP search
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

    # return a list of App groups (cns only), from LDAP.
    def self.listcns(filter='cn=*')
      # Note that hudson-job-admin is under ou=hudson hence need
      # to override Service.listcns and use subtree search
      ASF.search_subtree(base, filter, 'cn').flatten
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

  # <tt>ou=role</tt> subtree of <tt>ou=groups,dc=apache,dc=org</tt>, used for
  # committers (new) group only currently
  class RoleGroup < Service
    @base = 'ou=role,ou=groups,dc=apache,dc=org'
  end
end

if __FILE__ == $0
  $LOAD_PATH.unshift '/srv/whimsy/lib'
  require 'whimsy/asf/config'
  mem = ASF.members()
  puts mem.length
  puts mem.first.inspect
  memids = ASF.memberids()
  puts memids.length
  puts memids.first
  new = ASF.committers()
  puts new.length
  puts new.first.inspect
  newids = ASF.committerids()
  puts newids.length
  puts newids.first
  ASF::RoleGroup.listcns.map {|g| puts ASF::RoleGroup.find(g).dn}
  ASF::AppGroup.listcns.map {|g| puts ASF::AppGroup.find(g).dn}
end
