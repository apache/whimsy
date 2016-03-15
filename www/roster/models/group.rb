#
# Try each type of group until a match is found
#

class Group
  def self.list
    # start with groups that aren't PMCs
    groups = ASF::Group.list.map(&:id)
    groups -= ASF::Committee.list.map(&:id)
    groups.map! {|group| [group, "LDAP group"]}
    # add services...
    groups += ASF::Service.list.map {|service| [service, "LDAP service"]}

    # add authorization (asf and pit)
    begin
      groups += ASF::Authorization.new('asf').to_h.
        map {|id, list| [id, "ASF Auth"]}
    rescue # in case to_h does not work
      ASF::Authorization.new('asf').each do |id,list|
        groups += [[id, "ASF Auth"]]
      end
    end
    begin
      groups += ASF::Authorization.new('pit').to_h.
        map {|id, list| [id, "PIT Auth"]}
    rescue # in case to_h does not work
      ASF::Authorization.new('pit').each do |id,list|
        groups += [[id, "PIT Auth"]]
      end
    end

    groups.sort
  end

  def self.serialize(id)
    response = {}

    type = 'LDAP group'
    group = ASF::Group.find(id)

    if group.members.empty?
      type = 'LDAP service'
      group = ASF::Service.find(id)
    end

    if not group.members.empty?
      # LDAP group

      people = ASF::Person.preload('cn', group.members)

      response = {
        id: id,
        type: type,
        members: Hash[group.members.map {|person| [person.id, person.cn]}]
      }

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
          members: Hash[group.map {|person| [person.id, person.cn]}]
        }
      end
    end

    response
  end
end
