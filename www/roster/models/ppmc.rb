class PPMC
  def self.serialize(id, env)
    response = {}

    ppmc = ASF::Podling.find(id)
    return unless ppmc # Not found

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^(incubator-)?#{ppmc.mail_list}\b/
    end

    # Also look for non-ASF mod emails
    nonASFmails=Hash.new

    user = ASF::Person.find(env.user)
    if user.asf_member? or ppmc.members.include? user
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(ppmc.mail_list, true)
      load_emails # set up @people
      moderators.each { |list,mods| mods.each {|m| nonASFmails[m]='' unless m.end_with? '@apache.org'} }
      nonASFmails.each {|k,v|
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == k.downcase}
            nonASFmails[k] = person[:id]
          end
        end
      }
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
      enddate: ppmc.enddate.to_s,
      status: ppmc.status,
      mentors: ppmc.mentors,
      owners: ppmc.owners.map {|person| person.id},
      committers: ppmc.members.map {|person| person.id},
      roster: roster,
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      nonASFmails: nonASFmails,
      duration: ppmc.duration,
      podlingStatus: statusInfo,
      namesearch: ppmc.namesearch,
    }

    response
  end

  private

  def self.load_emails
    # recompute index if the data is 5 minutes old or older
    @people = nil if not @people_time or Time.now-@people_time >= 300
  
    if not @people
      # bulk loading the mail information makes things go faster
      mail = Hash[ASF::Mail.list.group_by(&:last).
        map {|person, list| [person, list.map(&:first)]}]
  
      # build a list of people, their public-names, and email addresses
      @people = ASF::Person.list.map {|person|
        result = {id: person.id, name: person.public_name, mail: mail[person]}
        result[:member] = true if person.asf_member?
        result
      }
  
      # cache
      @people_time = Time.now
    end
    @people
  end

end
