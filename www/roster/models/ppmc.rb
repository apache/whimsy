class PPMC
  def self.serialize(id, env)
    response = {}

    ppmc = ASF::Podling.find(id)

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^(incubator-)?#{ppmc.mail_list}\b/
    end

    user = ASF::Person.find(env.user)
    unless user.asf_member? or pmc.members.include? user
      lists = lists.select {|list, mode| mode == 'public'}
    end

    response = {
      id: id,
      display_name: ppmc.display_name,
      description: ppmc.description,
      schedule: ppmc.reporting,
      established: ppmc.startdate.to_s,
      mentors: ppmc.mentors,
      roster: ppmc.members.map {|person|
        [person.id, {name: person.public_name, member: person.asf_member?}]
      }.to_h,
      mail: Hash[lists.sort]
    }

    response
  end
end
