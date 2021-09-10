# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "service_count": 15,
#   "roster_counts": {
#     "asf-secretary": 4,
#     ...
#   },
#   "services": {
#     "svnadmins": {
#       "modifyTimestamp": "20111204095436Z",
#       "roster_count": 123,
#       "roster": ["uid",
#       ...
#       ]
#     },
#     ...
#   },
# }
#

require_relative 'public_json_common'

# gather service group info
entries = {}

groups = ASF::Service.preload # for performance

if groups.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

roster_counts = Hash.new(0)
lastStamp = ''
groups.keys.sort_by(&:name).each do |entry|
  next if entry.name == 'apldap' # infra team would prefer this not be publicized

  m = []
  entry.members.sort_by(&:name).each do |e|
    m << e.name
  end
  lastStamp = entry.modifyTimestamp if entry.modifyTimestamp > lastStamp
  entries[entry.name] = {
    createTimestamp: entry.createTimestamp,
    modifyTimestamp: entry.modifyTimestamp,
    roster_count: m.size,
    roster: m
  }
  roster_counts[entry.name] = m.size
end

info = {
  # Is there a use case for the last createTimestamp ?
  lastTimestamp: lastStamp,
  service_count: entries.size,
  roster_counts: roster_counts,
  services: entries,
}

public_json_output(info)

if changed? and @old_file
  # for validating UIDs
  uids = ASF::Person.list().map(&:id)
  entries.each do |name, entry|
    entry[:roster].each do |id|
      Wunderbar.warn "#{name}: unknown uid '#{id}'" unless uids.include?(id)
    end
  end
end
