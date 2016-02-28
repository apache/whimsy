class Group
  def self.serialize(id)
    response = {}

    type = 'LDAP group'
    group = ASF::Group.find(id)

    if group.members.empty?
      type = 'LDAP service'
      group = ASF::Service.find(id)
    end

    return if group.members.empty?

    people = ASF::Person.preload('cn', group.members)

    response = {
      id: id,
      type: type,
      members: Hash[group.members.map {|person| [person.id, person.cn]}]
    }

    response
  end
end
