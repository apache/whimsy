class Committee
  def self.serialize(id, env)
    response = {}

    pmc = ASF::Committee.find(id)
    members = pmc.members
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

    if pmc.roster.include? env.user or ASF::Person.find(env.user).asf_member?
      if File.exist? LIST_MODS
         modtime = File.mtime(LIST_MODS)
         mail_list = "#{pmc.mail_list}.apache.org"
         moderators = File.read(LIST_MODS).split(/\n\n/).map do |stanza|
           # list names can include '-': empire-db
           list = stanza.match(/\/([-\w]+\.apache\.org)\/(.*?)\//)
           next unless list and list[1] == mail_list
           # Drop the infra test lists
           next if list[2] =~ /^infra-[a-z]$/
           next if list[1] == 'incubator.apache.org' && list[2] =~ /^infra-dev2?$/
 
           ["#{list[2]}@#{list[1]}", stanza.scan(/^(.*@.*)/).flatten.sort]
        end
        moderators = moderators.compact.to_h
      end
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    response = {
      id: id,
      chair: pmc.chair && pmc.chair.id,
      display_name: pmc.display_name,
      description: pmc.description,
      schedule: pmc.schedule,
      report: pmc.report,
      site: pmc.site,
      established: pmc.established,
      ldap: Hash[members.map {|person| [person.id, person.cn]}],
      committers: Hash[committers.map {|person| [person.id, person.cn]}],
      asfmembers: (ASF.members & people).map(&:id),
      roster: pmc.roster,
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      project_info: info,
      image: image,
    }

    response
  end
end
