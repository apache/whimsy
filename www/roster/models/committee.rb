ASF::Committee.load_committee_info

class Committee
  def self.serialize(id)
    response = {}

    pmc = ASF::Committee.find(id)
    committers = ASF::Group.find(id).members

    ASF::Person.preload('cn', (pmc.members + committers).uniq)

    response = {
      id: id,
      display_name: pmc.display_name,
      description: pmc.description,
      schedule: pmc.schedule,
      report: pmc.report,
      site: pmc.site,
      established: pmc.established,
      ldap: Hash[pmc.members.map {|person| [person.id, person.cn]}],
      committers: Hash[committers.map {|person| [person.id, person.cn]}],
      roster: pmc.roster
    }

    response
  end
end
