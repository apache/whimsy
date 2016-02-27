class Group
  def self.serialize(id)
    response = {}

    group = ASF::Group.find(id)
    people = ASF::Person.preload('cn', group.members)

    response = {
      id: id,
      members: Hash[group.members.map {|person| [person.id, person.cn]}]
    }

    response
  end
end
