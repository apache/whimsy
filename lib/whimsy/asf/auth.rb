module ASF

  # parse the <tt>-authorization-template</tt> files contained within
  # <tt>infrastructure-puppet/modules/subversion_server/files/authorization</tt>
  class Authorization
    include Enumerable

    # Return the set of authorizations a given user (availid) has access to.
    def self.find_by_id(value)
      new.select {|auth, ids| ids.include? value}.map(&:first)
    end

    # Select a given <tt>-authorization-template</tt>, valid values are
    # <tt>asf</tt> and <tt>pit</tt>.
    def initialize(file='asf')
      @file = file
    end

    # Iteratively return each entry in the authorization file as a pair
    # of values: a name and list of ids.
    def each
      # TODO - should this read the Git repo directly?
      auth = ASF::Git.find('infrastructure-puppet')
      if auth
        auth += '/modules/subversion_server/files/authorization'
      else
        # SVN copy is no longer in use - see INFRA-11452
        raise Exception.new("Cannot find Git: infrastructure-puppet")
      end

      File.read("#{auth}/#{@file}-authorization-template").
        scan(/^([-\w]+)=(\w.*)$/).each do |pmc, ids|
        yield pmc, ids.split(',')
      end
    end

    unless Enumerable.instance_methods.include? :to_h
      # backwards compatibility for Ruby versions <= 2.0
      def to_h
        Hash[self.to_a]
      end
    end
  end

  class Person
    # return a list of ASF authorizations that contain this individual
    def auth
      @auths ||= ASF::Authorization.find_by_id(name)
    end
  end
end
