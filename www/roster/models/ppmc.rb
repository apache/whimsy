class PPMC
  def self.serialize(id, env)
    response = {}

    ppmc = ASF::Podling.find(id)
    return unless ppmc # Not found

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^(incubator-)?#{ppmc.mail_list}\b/
    end

    # separate out the known ASF members and extract any matching committer details
    unknownSubs = []
    asfMembers = []
    # Also look for non-ASF mod emails
    nonASFmails=Hash.new

    moderators = nil
    modtime = nil
    subscribers = nil # we get the counts only here
    subtime = nil
    pSubs = Array.new # private@ subscribers
    unMatchedSubs = [] # unknown private@ subscribers
    currentUser = ASF::Person.find(env.user)
    analysePrivateSubs = false # whether to show missing private@ subscriptions
    if currentUser.asf_member? or ppmc.members.include? currentUser
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(ppmc.mail_list, true)
      subscribers, subtime = ASF::MLIST.list_subscribers(ppmc.mail_list, true) # counts only
      analysePrivateSubs = currentUser.asf_member?
      unless analysePrivateSubs # check for private moderator if not already allowed access
        user_mail = currentUser.all_mail || []
        pMods = moderators["private@#{ppmc.mail_list}.apache.org"] || []
        analysePrivateSubs = !(pMods & user_mail).empty?
      end
      if analysePrivateSubs
        pSubs = ASF::MLIST.private_subscribers(ppmc.mail_list)[0]||[]
        unMatchedSubs=Set.new(pSubs) # init ready to remove matched mails
        pSubs.map!{|m| m.downcase} # for matching
      end

      moderators.each { |list,mods| mods.each {|m| nonASFmails[m]='' unless m.end_with? '@apache.org'} }
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    pmc = ASF::Committee.find('incubator')
    ipmc = pmc.owners
    incubator_committers = pmc.committers
    owners = ppmc.owners

    roster = ppmc.members.map {|person|
      notSubbed = false
      if analysePrivateSubs and owners.include? person
        allMail = person.all_mail.map{|m| m.downcase}
        notSubbed = (allMail & pSubs).empty?
        unMatchedSubs.delete_if {|k| allMail.include? k.downcase}
      end
      [person.id, {
        notSubbed: notSubbed,
        name: person.public_name, 
        member: person.asf_member?,
        icommit: incubator_committers.include?(person),
        role: (owners.include?(person) ? 'PPMC Member' : 'Committer'),
        githubUsername: (person.attrs['githubUsername'] || []).join(', ')
      }]
    }.to_h

    ppmc.mentors.each do |mentor|
      person = ASF::Person.find(mentor)
      roster[person.id] = {
        name: person.public_name, 
        member: person.asf_member?,
        ipmc: ipmc.include?(person),
        icommit: incubator_committers.include?(person),
        role: 'Mentor',
        githubUsername: (person.attrs['githubUsername'] || []).join(', ')
      }
      if analysePrivateSubs
        allMail = person.all_mail.map{|m| m.downcase}
        roster[person.id]['notSubbed'] = (allMail & pSubs).empty?
        unMatchedSubs.delete_if {|k| allMail.include? k.downcase}
      end
    end

    statusInfo = ppmc.podlingStatus || {news: []}

    if unMatchedSubs.length > 0 or nonASFmails.length > 0
      load_emails # set up @people
      unMatchedSubs.each{ |addr|
        who = nil
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == addr.downcase}
            who = person
          end
        end
        if who
          if who[:member]
            asfMembers << { addr: addr, person: who }
          else
            unknownSubs << { addr: addr, person: who }
          end
        else
          unknownSubs << { addr: addr, person: nil }
        end
      }
      nonASFmails.each {|k,v|
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == k.downcase}
            nonASFmails[k] = person[:id]
          end
        end
      }
    end

    response = {
      id: id,
      display_name: ppmc.display_name,
      description: ppmc.description,
      mail_list: ppmc.mail_list, # debug
      schedule: ppmc.reporting,
      monthly: ppmc.monthly,
      established: ppmc.startdate.to_s,
      enddate: ppmc.enddate.to_s,
      status: ppmc.status,
      mentors: ppmc.mentors,
      hasLDAP: ppmc.hasLDAP?,
      owners: ppmc.owners.map {|person| person.id},
      committers: ppmc.members.map {|person| person.id},
      roster: roster,
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      subscribers: subscribers,
      subtime: subtime,
      nonASFmails: nonASFmails,
      duration: ppmc.duration,
      podlingStatus: statusInfo,
      namesearch: ppmc.namesearch,
      analysePrivateSubs: analysePrivateSubs,
      unknownSubs: unknownSubs,
      asfMembers: asfMembers,
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
