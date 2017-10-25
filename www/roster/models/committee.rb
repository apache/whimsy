class Committee
  def self.serialize(id, env)
    response = {}

    pmc = ASF::Committee.find(id)
    members = pmc.owners
    committers = pmc.committers
    return if members.empty? and committers.empty?

    ASF::Committee.load_committee_info
    people = ASF::Person.preload('cn', (members + committers).uniq)

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^#{pmc.mail_list}\b/
    end

    comdev = ASF::SVN['asf/comdev/projects.apache.org/site/json/foundation']
    info = JSON.parse(File.read("#{comdev}/projects.json"))[id]

    image_dir = ASF::SVN.find('asf/infrastructure/site/trunk/content/img')
    image = Dir["#{image_dir}/#{id}.*"].map {|path| File.basename(path)}.last

    moderators = nil
    pSubs = Array.new # private@ subscribers
    unknownSubs = nil # unknown private@ subscribers
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
        pSubs = canonhost(ASF::MLIST.private_subscribers(pmc.mail_list)[0]||[])
        unknownSubs=Array.new(pSubs) # init ready to remove matched mails
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
        allMail = canonhost(person.all_mail)
        roster[person.id]['notSubbed'] = (allMail & pSubs).empty?
        unknownSubs -= allMail
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

    roster[pmc.chair.id]['role'] = 'PMC chair' if pmc.chair

    response = {
      id: id,
      chair: pmc.chair && pmc.chair.id,
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
      project_info: info,
      image: image,
      guinea_pig: ASF::Committee::GUINEAPIGS.include?(id),
      analysePrivateSubs: analysePrivateSubs,
      unknownSubs: unknownSubs,
    }

    response
  end

  private

  # canonicalise hostnames
  def self.canonhost(list)
    list.map {|i| i.sub(/@.+/) { |m| m.downcase } }
  end
end
