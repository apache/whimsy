class Committer
  def self.serialize(id, env)
    response = {}

    person = ASF::Person.find(id)
    person.reload!
    return unless person.attrs['cn']

    response[:id] = id

    response[:member] = person.asf_member?

    name = {}

    if person.icla
      name[:public_name] = person.public_name
      name[:legal_name] = person.icla.legal_name
    end

    unless person.attrs['cn'].empty?
      name[:ldap] = person.attrs['cn'].first.force_encoding('utf-8')
    end

    response[:name] = name

    response[:mail] = person.all_mail

    if person.pgp_key_fingerprints and not person.pgp_key_fingerprints.empty?
      response[:pgp] = person.pgp_key_fingerprints 
    end

    if person.attrs['asf-sascore']
      response[:sascore] = person.attrs['asf-sascore'].first
    end

    if person.attrs['githubUsername']
      response[:githubUsername] = person.githubUsername
    end

    response[:urls] = person.urls unless person.urls.empty?

    response[:committees] = person.committees.map(&:name)

    response[:groups] = person.services
    response[:committer] = []
    committees = ASF::Committee.list.map(&:id)
    person.groups.map(&:name).each do |group|
      if committees.include? group
        unless response[:committees].include? group
          response[:committer] << group 
        end
      else
        response[:groups] << group
      end
    end

    response[:committees].sort!
    response[:groups].sort!
    response[:committer].sort!

    if ASF::Person.find(env.user).asf_member?
      member = {}

      if person.asf_member?
        member[:info] = person.members_txt
        member[:status] = ASF::Member.status[id] || 'Active'
      else
        if person.member_nomination
          member[:nomination] = person.member_nomination
        end
      end

      response[:member] = member
    end

    response
  end
end
