require 'whimsy/asf/mlist'

class PPMC
  def self.serialize(id, env)

    ppmc = ASF::Podling.find(id)
    return unless ppmc # Not found

    committers = ppmc.members
    owners = ppmc.owners

    # separate out the known ASF members and extract any matching committer details
    unknownSubs = []
    asfMembers = []
    # Also look for non-ASF mod emails
    nonASFmails = {}

    # always needed: if not a member, for checking moderator status
    # and if a member, needed for showing list moderators
    # will be dropped later if insufficient karma
    moderators, modtime = ASF::MLIST.list_moderators(ppmc.mail_list)
    subscribers = nil # we get the counts only here
    subtime = nil
    pSubs = [] # private@ subscribers
    unMatchedSubs = [] # unknown private@ subscribers
    currentUser = ASF::Person.find(env.user)

    # Users have extra karma if they are either of the following:
    # ASF member or private@ list moderator (analysePrivateSubs)
    # PPMC member (in owner LDAP group) (isOwner)
    # These attributes grant access as follows:
    # both: can see (*) markers (PPMC members not subscribed to the private@ list)
    # both: can see moderator addresses for mailing lists
    # analysePrivateSubs: can see crosscheck of private@ list subscriptions

    analysePrivateSubs = currentUser.asf_member? # whether to show missing private@ subscriptions
    unless analysePrivateSubs # not an ASF member - are we a moderator?
      # TODO match using canonical emails
      user_mail = currentUser.all_mail || []
      pMods = moderators[ppmc.private_mail_list] || []
      analysePrivateSubs = !(pMods & user_mail).empty?
    end

    isOwner = false # default to not needed
    unless analysePrivateSubs
      isOwner = owners.include? currentUser
    end


    # Now get the data we are allowed to see
    if analysePrivateSubs or isOwner
      pSubs = ASF::MLIST.private_subscribers(ppmc.mail_list)[0]||[]
      subscribers, subtime = ASF::MLIST.list_subs(ppmc.mail_list, true) # counts only, no archivers
      if analysePrivateSubs
        unMatchedSubs=Set.new(pSubs) if analysePrivateSubs # init ready to remove matched mails
        moderators.each { |_, mods| mods.each {|m| nonASFmails[m]='' unless m.end_with? '@apache.org'} }
      end
      pSubs.map!(&:downcase) # for matching
      lists = ASF::MLIST.domain_lists(ppmc.mail_list, true)
    else
      lists = ASF::MLIST.domain_lists(ppmc.mail_list, false)
    end

    pmc = ASF::Committee.find('incubator')
    ipmc = pmc.owners
    incubator_committers = pmc.committers

    # Preload the committers; if a person has another role it will be set up below
    roster = committers.map {|person|
      [person.id, {
        # notSubbed does not apply
        name: person.public_name,
        member: person.asf_member?,
        icommit: incubator_committers.include?(person),
        role: 'Committer',
        githubUsername: (person.attrs['githubUsername'] || []).join(', ')
      }]
    }.to_h

    # Merge the PPMC members (owners)
    owners.each do |person|
      roster[person.id] = {
        name: person.public_name,
        member: person.asf_member?,
        icommit: incubator_committers.include?(person),
        role: 'PPMC Member',
        githubUsername: (person.attrs['githubUsername'] || []).join(', ')
      }
      if analysePrivateSubs or isOwner
        allMail = person.all_mail.map{|m| ASF::Mail.to_canonical(m.downcase)}
        roster[person.id]['notSubbed'] = true if (allMail & pSubs.map{|m| ASF::Mail.to_canonical(m)}).empty?
      end
      if analysePrivateSubs
        unMatchedSubs.delete_if {|k| allMail.include? ASF::Mail.to_canonical(k.downcase)}
      end
    end

    # Finally merge the mentors
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
      if analysePrivateSubs or isOwner
        allMail = person.all_mail.map{|m| ASF::Mail.to_canonical(m.downcase)}
        roster[person.id]['notSubbed'] = true if (allMail & pSubs.map{|m| ASF::Mail.to_canonical(m)}).empty?
      end
      if analysePrivateSubs or isOwner
        unMatchedSubs.delete_if {|k| allMail.include? ASF::Mail.to_canonical(k.downcase)}
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
          if person[:mail].any? {|mail| ASF::Mail.to_canonical(mail.downcase) == ASF::Mail.to_canonical(k.downcase)}
            nonASFmails[k] = person[:id]
          end
        end
      }
    end

    # drop moderators if there is no karma
    unless isOwner or analysePrivateSubs
      moderators = modtime = nil
    end

    ret = {
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
      owners: owners.map(&:id),
      committers: committers.map(&:id),
      roster: roster,
      mail: lists.sort.to_h,
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
    # Don't add unnecessary settings
    ret[:isOwner] = isOwner if isOwner
    return ret

  end

  private

  def self.load_emails
    # recompute index if the data is 5 minutes old or older
    @people = nil if not @people_time or Time.now - @people_time >= 300

    unless @people
      # bulk loading the mail information makes things go faster
      # TODO: it is still expensive
      mail = ASF::Mail.list.group_by(&:last).transform_values {|list| list.map(&:first)}

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
