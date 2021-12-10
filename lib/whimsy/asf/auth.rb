module ASF

  # parse the <tt>-authorization-template</tt> files contained within
  # <tt>infrastructure-puppet/modules/subversion_server/files/authorization</tt>
  class Authorization
    include Enumerable

    # N.B. This data is maintained by a cron job on the Whimsy server, which has access
    PUPPET_PATH = '/srv/puppet-data/authorization' # Puppet auth data is stored here

    # Return the set of authorizations a given user (availid) has access to.
    def self.find_by_id(value)
      new.select {|_auth, ids| ids.include? value}.map(&:first)
    end

    # Select a given <tt>-authorization-template</tt>, valid values are
    # <tt>asf</tt> and <tt>pit</tt>.
    # The optional <tt>auth_path</tt> parameter allows the directory path to be overridden
    # This is intended for testing only
    def initialize(file='asf', auth_path=nil)
      raise ArgumentError("Invalid file: #{file}") unless %w(asf pit).include? file
      if auth_path
        require 'wunderbar'
        Wunderbar.warn "Overriding Git infrastructure-puppet auth path as: #{auth_path}"
        @auth = auth_path
      else
        @auth = PUPPET_PATH
      end
      @file = file
    end

    # Iteratively return each non_LDAP entry in the authorization file as a pair
    # of values: a name and list of ids.
    def each
      # extract the xxx={auth} names
      groups = read_auth.scan(/^([-\w]+)=\{auth\}/).flatten
      # extract the group = list details and return the appropriate ones
      read_conf.each do |pmc, ids|
        yield pmc, ids if groups.include? pmc
      end
    end

    # Return the auth path used to find asf-auth and pit-auth
    def path
      @auth
    end

    private

    # read the config file - extract the [explicit] section
    def read_conf
      YAML.safe_load(File.read(File.join(@auth, 'svnauthz.yaml')))['explicit']
    end

    # read the auth template; extract [groups]
    def read_auth
      File.read(File.join(@auth, "#{@file}-authorization-template")).scan(/^\[groups\].*^\[/m).first rescue ''
    end
  end

  class Person
    # return a list of ASF authorizations that contain this individual
    def auth
      @auths ||= ASF::Authorization.find_by_id(name)
    end
  end

end
