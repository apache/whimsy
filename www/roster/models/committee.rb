class Committee
  def self.serialize(id)
    response = {}

    pmc = ASF::Committee.find(id)
    committers = ASF::Group.find(id).members

    ASF::Committee.load_committee_info
    people = ASF::Person.preload('cn', (pmc.members + committers).uniq)

    prefix = pmc.mail_list + '-'
    lists = ASF::Mail.lists(true).select {|list| list.start_with? prefix}

    response = {
      id: id,
      chair: pmc.chair && pmc.chair.id,
      display_name: pmc.display_name,
      description: pmc.description,
      schedule: pmc.schedule,
      report: pmc.report,
      site: pmc.site,
      established: pmc.established,
      ldap: Hash[pmc.members.map {|person| [person.id, person.cn]}],
      committers: Hash[committers.map {|person| [person.id, person.cn]}],
      roster: pmc.roster,
      mail: Hash[lists]
    }

    response
  end
end
