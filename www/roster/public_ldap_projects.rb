# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "projects": {
#     "airflow": {
#       "createTimestamp": "20170118154251Z",
#       "modifyTimestamp": "20170118154251Z",
#       "members": [
#         "abcd",
#       ],
#       "owners": [
#         "abcd",
#       ],
#        "pmc": true|false, (may be absent)
#        "officer": "abcd", (may be absent)
#        "podling": "current|graduated|retired" (may be absent)
#     },
#     ...
#   },
# }
#

require_relative 'public_json_common'

# gather project group info
entries = {}

projects = ASF::Project.preload # for performance

if projects.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

# committee status
committees = ASF::Committee.load_committee_info.map {|committee|
  [committee.name.gsub(/[^-\w]/, ''), committee]
}.to_h

# podling status
pods = ASF::Podling.list.map {|podling| [podling.name, podling.status]}.to_h

lastStamp = ''
projects.keys.sort_by(&:name).each do |entry|
  next if entry.name == 'apldap' # infra team would prefer this not be publicized

  m = []
  entry.members.sort_by(&:name).each do |e|
    m << e.name
  end
  o = []
  entry.owners.sort_by(&:name).each do |e|
    o << e.name
  end
  lastStamp = entry.modifyTimestamp if entry.modifyTimestamp > lastStamp
  entries[entry.name] = {
    createTimestamp: entry.createTimestamp,
    modifyTimestamp: entry.modifyTimestamp,
    members: m,
    owners: o
  }
  committee = committees[entry.name]
  if committee
    if committee.pmc?
      entries[entry.name][:pmc]=true
    elsif ASF::Project.find(committee.name).dn
      entries[entry.name][:officer]=committee.chair.id
    end
  end
  pod = pods[entry.name]
  if pod
    entries[entry.name][:podling]=pod
  end
end

info = {
  # Is there a use case for the last createTimestamp ?
  lastTimestamp: lastStamp,
  projects: entries,
}

public_json_output(info)

if changed? and @old_file
  # for validating UIDs
  uids = ASF::Person.list().map(&:id)
  entries.each do |name, entry|
    entry[:members].each do |id|
      Wunderbar.warn "#{name}: unknown member uid '#{id}'" unless uids.include?(id)
    end
    entry[:owners].each do |id|
      Wunderbar.warn "#{name}: unknown owner uid '#{id}'" unless uids.include?(id)
    end
  end
end
