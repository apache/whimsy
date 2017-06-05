class PPMC
  def self.serialize(id, env)
    response = {}

    ppmc = ASF::Podling.find(id)

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^(incubator-)?#{ppmc.mail_list}\b/
    end

    user = ASF::Person.find(env.user)
    if user.asf_member? or ppmc.members.include? user
      if File.exist? LIST_MODS
         mail_list = ppmc.mail_list
         moderators = File.read(LIST_MODS).split(/\n\n/).map do |stanza|
           list = stanza.match(/(\w+)\.apache\.org\/(.*?)\//)
           next unless list and 
             (list[1] == mail_list or list[2] =~ /^#{mail_list}-/)
 
           ["#{list[2]}@#{list[1]}.apache.org", 
             stanza.scan(/^(.*@.*)/).flatten.sort]
        end
        moderators = moderators.compact.to_h
      end
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    ipmc = ASF::Committee.find('incubator').members
    incubator_committers = ASF::Group.find('incubator').members

    roster = ppmc.members.map {|person|
      [person.id, {
        name: person.public_name, 
        member: person.asf_member?,
        icommit: incubator_committers.include?(person)
      }]
    }.to_h

    ppmc.mentors.each do |mentor|
      person = ASF::Person.find(mentor)
      roster[person.id] = {
        name: person.public_name, 
        member: person.asf_member?,
        ipmc: ipmc.include?(person),
        icommit: incubator_committers.include?(person)
      }
    end

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
    }

    response
  end
end
