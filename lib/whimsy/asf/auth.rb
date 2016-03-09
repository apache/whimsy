module ASF

  class Authorization
    include Enumerable

    def self.find_by_id(value)
      new.select {|auth, ids| ids.include? value}.map(&:first)
    end

    def initialize(file='asf')
      @file = file
    end

    def each
      auth = ASF::Git.find('infrastructure-puppet')
      if auth
        auth += '/modules/subversion_server/files/authorization'
      else
        auth = ASF::SVN['infra/infrastructure/trunk/subversion/authorization']
      end

      File.read("#{auth}/#{@file}-authorization-template").
        scan(/^([-\w]+)=(\w.*)$/).each do |pmc, ids|
        yield pmc, ids.split(',')
      end
    end
  end

  class Person
    def auth
      @auths ||= ASF::Authorization.find_by_id(name)
    end
  end
end
