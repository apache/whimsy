class Committer
  def self.serialize(id)
    response = {}

    person = ASF::Person.find(id)

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

    response[:urls] = person.urls unless person.urls.empty?

    response[:groups] = person.groups.map(&:name)

    response[:committees] = person.committees.map(&:name)

    response
  end
end
