class Committee
  def self.serialize(id, env)

    pmc = ASF::Committee.find(id)
    return unless pmc.pmc? # Only show PMCs
    members = pmc.owners
    committers = pmc.committers
    return if members.empty? and committers.empty?

    ASF::Committee.load_committee_info
    # We'll be needing the mail data later
    ASF::Person.preload(['cn', 'mail', 'asf-altEmail', 'githubUsername'], (members + committers).uniq)

    comdev = ASF::SVN['comdev-foundation']
    info = JSON.parse(File.read(File.join(comdev, 'projects.json')))[id]

    image = ASF::SiteImage.find(id)

    moderators = nil
    modtime = nil
    subscribers = nil # we get the counts only here
    subtime = nil
    pSubs = [] # private@ subscribers
    unMatchedSubs = [] # unknown private@ subscribers
    unMatchedSecSubs = [] # unknown security@ subscribers
    currentUser = ASF::Person.find(env.user)
    analysePrivateSubs = false # whether to show missing private@ subscriptions
    if pmc.roster.include? env.user or currentUser.asf_member?
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(pmc.mail_list)
      subscribers, subtime = ASF::MLIST.list_subs(pmc.mail_list) # counts only, no archivers
      analysePrivateSubs = currentUser.asf_member?
      unless analysePrivateSubs # check for private moderator if not already allowed access
        # TODO match using canonical emails
        user_mail = currentUser.all_mail || []
        pMods = moderators["private@#{pmc.mail_list}.apache.org"] || []
        analysePrivateSubs = !(pMods & user_mail).empty?
      end
      if analysePrivateSubs
        pSubs = ASF::MLIST.private_subscribers(pmc.mail_list)[0]||[]
        unMatchedSubs=Set.new(pSubs) # init ready to remove matched mails
        pSubs.map!(&:downcase) # for matching
        sSubs = ASF::MLIST.security_subscribers(pmc.mail_list)[0]||[]
        unMatchedSecSubs=Set.new(sSubs) # init ready to remove matched mails
      end
      lists = ASF::MLIST.domain_lists(pmc.mail_list, true)
    else
      lists = ASF::MLIST.domain_lists(pmc.mail_list, false)
    end

    roster = pmc.roster.dup # from committee-info
    # ensure PMC members are all processed even they don't belong to the owner group
    roster.each do |key, value|
      value[:role] = 'PMC member'
      next if pmc.ownerids.include?(key) # skip the rest (expensive) if person is in the owner group
      person = ASF::Person[key]
      next unless person  # in case of missing entry (e.g. renamed uid)
      if analysePrivateSubs
        # Analyse the subscriptions, matching against canonicalised personal emails
        allMail = person.all_mail.map{|m| ASF::Mail.to_canonical(m.downcase)}
        # pSubs is already downcased
        # TODO should it be canonicalised as well above?
        roster[key]['notSubbed'] = (allMail & pSubs.map{|m| ASF::Mail.to_canonical(m)}).empty?
        unMatchedSubs.delete_if {|k| allMail.include? ASF::Mail.to_canonical(k.downcase)}
        unMatchedSecSubs.delete_if {|k| allMail.include? ASF::Mail.to_canonical(k.downcase)}
      end
      roster[key]['githubUsername'] = (person.attrs['githubUsername'] || []).join(', ')
    end

    members.each do |person| # process the owners
      roster[person.id] ||= {
        name: person.public_name,
        role: 'PMC member' # TODO not strictly true, as CI is the canonical source
      }
      if analysePrivateSubs
        # Analyse the subscriptions, matching against canonicalised personal emails
        allMail = person.all_mail.map{|m| ASF::Mail.to_canonical(m.downcase)}
        # pSubs is already downcased
        # TODO should it be canonicalised as well above?
        roster[person.id]['notSubbed'] = (allMail & pSubs.map{|m| ASF::Mail.to_canonical(m)}).empty?
        unMatchedSubs.delete_if {|k| allMail.include? ASF::Mail.to_canonical(k.downcase)}
        unMatchedSecSubs.delete_if {|k| allMail.include? ASF::Mail.to_canonical(k.downcase)}
      end
      roster[person.id]['ldap'] = true
      roster[person.id]['githubUsername'] = (person.attrs['githubUsername'] || []).join(', ')
    end

    committers.each do |person|
      roster[person.id] ||= {
        name: person.public_name,
        role: 'Committer'
      }
      roster[person.id]['githubUsername'] = (person.attrs['githubUsername'] || []).join(', ')
    end

    roster.each {|k, v| v[:member] = ASF::Person.find(k).asf_member?}

    if pmc.chair and roster[pmc.chair.id]
      roster[pmc.chair.id]['role'] = 'PMC chair'
    end

    # separate out the known ASF members and extract any matching committer details
    unknownSubs = [] # unknown private@ subscribers: not PMC or ASF
    asfMembers = []
    unknownSecSubs = [] # unknown security@ subscribers: not PMC or ASF
    # Also look for non-ASF mod emails
    nonASFmails = {}
    moderators&.each { |_, mods| mods.each {|m| nonASFmails[m] = '' unless m.end_with? '@apache.org'} }
    if unMatchedSubs.length > 0 or nonASFmails.length > 0 or unMatchedSecSubs.length > 0
      load_emails # set up @people
      unMatchedSubs.each { |addr|
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
      nonASFmails.each {|k, _|
        @people.each do |person|
          if person[:mail].any? {|mail| ASF::Mail.to_canonical(mail.downcase) == ASF::Mail.to_canonical(k.downcase)}
            nonASFmails[k] = person[:id]
          end
        end
      }
      unMatchedSecSubs.each { |addr|
        who = nil
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == addr.downcase}
            who = person
          end
        end
        if who
          unless who[:member]
            unknownSecSubs << { addr: addr, person: who }
          end
        else
          unknownSecSubs << { addr: addr, person: nil }
        end
      }
    end

    pmc_chair = false
    if pmc.chair
      pmcchairs = ASF::Service.find('pmc-chairs')
      pmc_chair = pmcchairs.members.include? pmc.chair
    end
    return {
      id: id,
      chair: pmc.chair&.id,
      pmc_chair: pmc_chair,
      display_name: pmc.display_name,
      description: pmc.description,
      schedule: pmc.schedule,
      report: pmc.report,
      site: pmc.site,
      established: pmc.established,
      ldap: members.map(&:id),
      members: pmc.roster.keys,
      committers: committers.map(&:id),
      roster: roster,
      mail: lists.sort.to_h,
      moderators: moderators,
      modtime: modtime,
      subscribers: subscribers,
      subtime: subtime,
      nonASFmails: nonASFmails,
      project_info: info,
      image: image,
      analysePrivateSubs: analysePrivateSubs,
      unknownSubs: unknownSubs,
      asfMembers: asfMembers,
      unknownSecSubs: unknownSecSubs,
    }

  end

  private

  def self.load_emails
    # recompute index if the data is 5 minutes old or older
    @people = nil if not @people_time or Time.now-@people_time >= 300

    unless @people
      # bulk loading the mail information makes things go faster
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
