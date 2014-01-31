#!/usr/bin/ruby

module Angular::AsfRosterServices

  class LDAP
    @@fetching = false

    @@index = {
      services: {},
      committers: {},
      pmcs: {},
      groups: {},
      members: []
    }

    def self.get()
      unless @@fetching
        @@fetching = true
        $http.get('json/ldap').success do |result|
          angular.copy result.services, @@index.services
          angular.copy result.committers, @@index.committers
          angular.copy result.pmcs, @@index.pmcs
          angular.copy result.groups, @@index.groups
          angular.copy result.groups.member.memberUid, @@index.members
        end
      end

      return @@index
    end

    def self.committers
      return self.get().committers
    end

    def self.members
      return self.get().members
    end

    def self.services
      return self.get().services
    end

    def self.pmcs
      return self.get().pmcs
    end

    def self.groups
      return self.get().groups
    end
  end
end
