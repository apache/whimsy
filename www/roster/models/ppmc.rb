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

    response = {
      id: id,
      display_name: ppmc.display_name,
      description: ppmc.description,
      schedule: ppmc.reporting,
      established: ppmc.startdate.to_s,
      mentors: ppmc.mentors,
      owners: ppmc.owners.map {|person| person.id},
      roster: ppmc.members.map {|person|
        [person.id, {name: person.public_name, member: person.asf_member?}]
      }.to_h,
      mail: Hash[lists.sort],
      moderators: moderators,
    }

    response
  end
end
