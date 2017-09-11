class PPMC
  def self.serialize(id, env)
    response = {}

    ppmc = ASF::Podling.find(id)
    return unless ppmc # Not found

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^(incubator-)?#{ppmc.mail_list}\b/
    end

    user = ASF::Person.find(env.user)
    if user.asf_member? or ppmc.members.include? user
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(ppmc.mail_list, true)
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    pmc = ASF::Committee.find('incubator')
    ipmc = pmc.owners
    incubator_committers = pmc.committers
    owners = ppmc.owners

    roster = ppmc.members.map {|person|
      [person.id, {
        name: person.public_name, 
        member: person.asf_member?,
        icommit: incubator_committers.include?(person),
        role: (owners.include?(person) ? 'PPMC Member' : 'Committer')
      }]
    }.to_h

    ppmc.mentors.each do |mentor|
      person = ASF::Person.find(mentor)
      roster[person.id] = {
        name: person.public_name, 
        member: person.asf_member?,
        ipmc: ipmc.include?(person),
        icommit: incubator_committers.include?(person),
        role: 'Mentor'
      }
    end

    statusInfo = ppmc.podlingStatus || {news: []}

    response = {
      id: id,
      display_name: ppmc.display_name,
      description: ppmc.description,
      schedule: ppmc.reporting,
      monthly: ppmc.monthly,
      established: ppmc.startdate.to_s,
      mentors: ppmc.mentors,
      owners: ppmc.owners.map {|person| person.id},
      committers: ppmc.members.map {|person| person.id},
      roster: roster,
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      duration: ppmc.duration,
      podlingStatus: statusInfo,
      namesearch: ppmc.namesearch,
    }

    response
  end
end
