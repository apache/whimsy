class NonPMC
  def self.serialize(id, env)
    response = {}

    cttee = ASF::Committee.find(id)
    return unless cttee.nonpmc?
    members = cttee.owners
    committers = cttee.committers

    ASF::Committee.load_committee_info
    # We'll be needing the mail data later
    people = ASF::Person.preload(['cn', 'mail', 'asf-altEmail', 'githubUsername'], (members + committers).uniq)

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^#{cttee.mail_list}\b/
    end

    comdev = ASF::SVN['comdev-foundation']
    info = JSON.parse(File.read(File.join(comdev, 'projects.json')))[id]

    image_dir = ASF::SVN.find('site-img')
    image = Dir[File.join(image_dir, "#{id}.*")].map {|path| File.basename(path)}.last

    moderators = nil
    modtime = nil
    subscribers = nil # we get the counts only here
    subtime = nil
    pSubs = Array.new # private@ subscribers
    unMatchedSubs = [] # unknown private@ subscribers
    unMatchedSecSubs = [] # unknown security@ subscribers
    currentUser = ASF::Person.find(env.user)
    # TODO does not make sense for non-PMCs - remove the code
    analysePrivateSubs = false # whether to show missing private@ subscriptions
    if cttee.roster.include? env.user or currentUser.asf_member?
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(cttee.mail_list)
      subscribers, subtime = ASF::MLIST.list_subscribers(cttee.mail_list) # counts only
      analysePrivateSubs = currentUser.asf_member?
      unless analysePrivateSubs # check for private moderator if not already allowed access
        user_mail = currentUser.all_mail || []
        pMods = moderators["private@#{cttee.mail_list}.apache.org"] || []
        analysePrivateSubs = !(pMods & user_mail).empty?
      end
      if analysePrivateSubs
        pSubs = ASF::MLIST.private_subscribers(cttee.mail_list)[0]||[]
        unMatchedSubs=Set.new(pSubs) # init ready to remove matched mails
        pSubs.map!{|m| m.downcase} # for matching
        sSubs = ASF::MLIST.security_subscribers(cttee.mail_list)[0]||[]
        unMatchedSecSubs=Set.new(sSubs) # init ready to remove matched mails
      end
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    roster = cttee.roster.dup
    roster.each {|key, info| info[:role] = 'Committee member'}

    members.each do |person|
      roster[person.id] ||= {
        name: person.public_name, 
        role: 'Committee member'
      }
      if analysePrivateSubs
        allMail = person.all_mail.map{|m| m.downcase}
        roster[person.id]['notSubbed'] = (allMail & pSubs).empty?
        unMatchedSubs.delete_if {|k| allMail.include? k.downcase}
        unMatchedSecSubs.delete_if {|k| allMail.include? k.downcase}
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

    roster.each {|id, info| info[:member] = ASF::Person.find(id).asf_member?}

    if cttee.chair and roster[cttee.chair.id]
      roster[cttee.chair.id]['role'] = 'PMC chair' 
    end

    # separate out the known ASF members and extract any matching committer details
    unknownSubs = [] # unknown private@ subscribers: not PMC or ASF
    asfMembers = []
    unknownSecSubs = [] # unknown security@ subscribers: not PMC or ASF
    # Also look for non-ASF mod emails
    nonASFmails=Hash.new
    if moderators
      moderators.each { |list,mods| mods.each {|m| nonASFmails[m]='' unless m.end_with? '@apache.org'} }
    end
    if unMatchedSubs.length > 0 or nonASFmails.length > 0 or unMatchedSecSubs.length > 0
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
      unMatchedSecSubs.each{ |addr|
        who = nil
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == addr.downcase}
            who = person
          end
        end
        if who
          unless who[:member]
            unknownSubs << { addr: addr, person: who }
          end
        else
          unknownSecSubs << { addr: addr, person: nil }
        end
      }
    end

    pmc_chair = false
    if cttee.chair
      pmcchairs = ASF::Service.find('cttee-chairs')
      pmc_chair = pmcchairs.members.include? cttee.chair
    end
    response = {
      id: id,
      chair: cttee.chair && cttee.chair.id,
      pmc_chair: pmc_chair,
      display_name: cttee.display_name,
      description: cttee.description,
      schedule: cttee.schedule,
      report: cttee.report,
      site: cttee.site,
      established: cttee.established,
      ldap: members.map(&:id),
      members: cttee.roster.keys,
      committers: committers.map(&:id),
      roster: roster,
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      subscribers: subscribers,
      subtime: subtime,
      nonASFmails: nonASFmails,
      project_info: info,
      image: image,
      guinea_pig: ASF::Committee::GUINEAPIGS.include?(id),
      analysePrivateSubs: analysePrivateSubs,
      unknownSubs: unknownSubs,
      asfMembers: asfMembers,
      unknownSecSubs: unknownSecSubs,
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
