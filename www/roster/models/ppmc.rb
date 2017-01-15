class PPMC
  def self.serialize(id)
    response = {}

    ppmc = ASF::Podling.find(id)

    response = {
      id: id,
      display_name: ppmc.display_name,
      description: ppmc.description,
      schedule: ppmc.reporting,
      established: ppmc.startdate,
      mentors: ppmc.mentors,
      roster: ppmc.members.map {|person|
        [person.id, {name: person.public_name, member: person.asf_member?}]
      }.to_h,
    }

    response
  end
end
