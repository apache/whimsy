#
# Try each type of group until a match is found
#

class Group
  def self.list
    # start with groups that aren't PMCs or podlings etc
    groups = ASF::Group.list.map(&:id)
    groups -= ASF::Project.listids # These are PMCs and podlings and other committees
    groups.map! {|group| [group, 'LDAP group']}

    # add services...
    groups += ASF::Service.listcns.reject {|s| s == 'apldap'}.map {|service| [service, 'LDAP service']}

    # add authorization (asf and pit)
    groups += ASF::Authorization.new('asf').to_h.
      map {|id, _list| [id, 'ASF Auth']}

    groups += ASF::Authorization.new('pit').to_h.
      map {|id, _list| [id, 'PIT Auth']}

    # add authorization groups (LDAP)
    groups += ASF::AuthGroup.listcns.map {|group| [group, 'LDAP Auth Group']}

    groups.sort
  end

  # The id 'svnadmins' currently has two definitions
  # LDAP Auth Group and LDAP service
  # See INFRA-24565
  # So the type can now be provided as a work-round
  def self.serialize(id, itype=nil)
    response = {}

    member_status = ASF::Member.member_statuses

    type = 'LDAP group'
    group = ASF::Group.find(id)

    unless group.hasLDAP? or (%w{treasurer svnadmins}.include?(id) and (itype !~ %r{Auth Group}i))
      type = 'LDAP auth group'
      group = ASF::AuthGroup.find(id)
    end

    unless group.hasLDAP?
      type = 'LDAP service'
      group = ASF::Service.find(id)
    end

    if group.hasLDAP?
      # LDAP group

      _people = ASF::Person.preload('cn', group.members)

      response = {
        id: id,
        type: type,
        dn: (group.dn rescue ''), # not all groups have a DN
        members: Hash[group.members.map {|person| [person.id, (person.cn rescue '**Entry missing from LDAP people**')]}], # if id not in people
        memberstatus: group.members.map{|person| [person.id, member_status[person.id]]}.to_h,
      }

      if id == 'hudson-jobadmin'
        response[:owners] = ASF::Service.find('hudson-admin').members.
          map {|owner| owner.id}
      end

    else

      type = 'asf-auth'
      group = ASF::Authorization.new('asf').to_h[id]

      unless group
        type = 'pit-auth'
        group = ASF::Authorization.new('pit').to_h[id]
      end

      if group
        group.map! {|id1| ASF::Person.find(id1)}

        # auth group
        _people = ASF::Person.preload('cn', group)

        response = {
          id: id,
          type: type,
          dn: (group.dn rescue ''), # not all groups have a DN
          members: Hash[group.map {|person| [person.id, person.cn]}],
          memberstatus: group.map{|person| [person.id, member_status[person.id]]}.to_h,
        }
      end
    end

    response
  end
end
