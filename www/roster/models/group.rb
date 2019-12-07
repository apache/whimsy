#
# Try each type of group until a match is found
#

class Group
  def self.list
    # start with groups that aren't PMCs or podlings etc
    groups = ASF::Group.list.map(&:id)
    groups -= ASF::Project.listids # These are PMCs and podlings and other committees
    groups.map! {|group| [group, "LDAP group"]}

    # add services...
    groups += ASF::Service.listcns.reject{|s| s=='apldap'}.map {|service| [service, "LDAP service"]}

    # add authorization (asf and pit)
    groups += ASF::Authorization.new('asf').to_h.
      map {|id, list| [id, "ASF Auth"]}

    groups += ASF::Authorization.new('pit').to_h.
      map {|id, list| [id, "PIT Auth"]}

    # add authorization groups (LDAP)
    groups += ASF::AuthGroup.listcns.map {|group| [group, "LDAP Auth Group"]}

    # add app groups
    groups += ASF::AppGroup.listcns.map {|app| [app, "LDAP app group"]}

    groups.sort
  end

  def self.serialize(id)
    response = {}

    type = 'LDAP group'
    group = ASF::Group.find(id)

    unless group.hasLDAP?
      type = 'LDAP auth group'
      group = ASF::AuthGroup.find(id)
    end

    unless group.hasLDAP?
      type = 'LDAP service'
      group = ASF::Service.find(id)
    end

    unless group.hasLDAP?
      type = 'LDAP app group'
      group = ASF::AppGroup.find(id)
    end

    if group.hasLDAP?
      # LDAP group

      people = ASF::Person.preload('cn', group.members)

      response = {
        id: id,
        type: type,
        dn: (group.dn rescue ''), # not all groups have a DN
        members: Hash[group.members.map {|person| [person.id, (person.cn rescue '**Entry missing from LDAP people**')]}], # if id not in people
        asfmembers: group.members.select{|person| ASF.members.include?(person)}.map(&:id),
      }

      if id == 'hudson-jobadmin'
        response[:owners] = ASF::Service.find('hudson-admin').members.
          map {|owner| owner.id}
      end

    else

      type = 'asf-auth'
      group = ASF::Authorization.new('asf').to_h[id]

      if not group
        type = 'pit-auth'
        group = ASF::Authorization.new('pit').to_h[id]
      end

      if group
        group.map! {|id| ASF::Person.find(id)}

        # auth group
        people = ASF::Person.preload('cn', group)

        response = {
          id: id,
          type: type,
          dn: (group.dn rescue ''), # not all groups have a DN
          members: Hash[group.map {|person| [person.id, person.cn]}],
          asfmembers: group.select{|person| ASF.members.include?(person)}.map(&:id),
        }
      end
    end

    response
  end
end
