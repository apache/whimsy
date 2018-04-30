class Committee
  def self.serialize(id, env)
    response = {}

    pmc = ASF::Committee.find(id)
    members = pmc.owners
    committers = pmc.committers
    return if members.empty? and committers.empty?

    ASF::Committee.load_committee_info
    # We'll be needing the mail data later
    people = ASF::Person.preload(['cn', 'mail', 'asf-altEmail'], (members + committers).uniq)

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^#{pmc.mail_list}\b/
    end

    comdev = ASF::SVN['asf/comdev/projects.apache.org/trunk/site/json/foundation']
    info = JSON.parse(File.read("#{comdev}/projects.json"))[id]

    image_dir = ASF::SVN.find('asf/infrastructure/site/trunk/content/img')
    image = Dir["#{image_dir}/#{id}.*"].map {|path| File.basename(path)}.last

    moderators = nil
    pSubs = Array.new # private@ subscribers
    unMatchedSubs = [] # unknown private@ subscribers
    currentUser = ASF::Person.find(env.user)
    analysePrivateSubs = false # whether to show missing private@ subscriptions
    if pmc.roster.include? env.user or currentUser.asf_member?
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(pmc.mail_list)
      analysePrivateSubs = currentUser.asf_member?
      unless analysePrivateSubs # check for private moderator if not already allowed access
        user_mail = currentUser.all_mail || []
        pMods = moderators["private@#{pmc.mail_list}.apache.org"] || []
        analysePrivateSubs = !(pMods & user_mail).empty?
      end
      if analysePrivateSubs
        pSubs = ASF::MLIST.private_subscribers(pmc.mail_list)[0]||[]
        unMatchedSubs=Set.new(pSubs) # init ready to remove matched mails
        pSubs.map!{|m| m.downcase} # for matching
      end
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    roster = pmc.roster.dup
    roster.each {|key, info| info[:role] = 'PMC member'}

    members.each do |person|
      roster[person.id] ||= {
        name: person.public_name, 
        role: 'PMC member'
      }
      if analysePrivateSubs
        allMail = person.all_mail.map{|m| m.downcase}
        roster[person.id]['notSubbed'] = (allMail & pSubs).empty?
        unMatchedSubs.delete_if {|k| allMail.include? k.downcase}
      end
      roster[person.id]['ldap'] = true
    end

    committers.each do |person|
      roster[person.id] ||= {
        name: person.public_name,
        role: 'Committer'
      }
    end

    roster.each {|id, info| info[:member] = ASF::Person.find(id).asf_member?}

    if pmc.chair and roster[pmc.chair.id]
      roster[pmc.chair.id]['role'] = 'PMC chair' 
    end

    # separate out the known ASF members and extract any matching committer details
    unknownSubs = []
    asfMembers = []
    # Also look for non-ASF mod emails
    nonASFmails=Hash.new
    if moderators
      moderators.each { |list,mods| mods.each {|m| nonASFmails[m]='' unless m.end_with? '@apache.org'} }
    end
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

    pmc_chair = false
    if pmc.chair
      pmcchairs = ASF::Service.find('pmc-chairs')
      pmc_chair = pmcchairs.members.include? pmc.chair
    end
    response = {
      id: id,
      chair: pmc.chair && pmc.chair.id,
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
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      nonASFmails: nonASFmails,
      project_info: info,
      image: image,
      guinea_pig: ASF::Committee::GUINEAPIGS.include?(id),
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
