# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "services": {
#     "svnadmins": {
#       "modifyTimestamp": "20111204095436Z",
#       "roster": ["uid",
#       ...
#       ]
#     },
#     ...
#   },
# }
#

require_relative 'public_json_common'

# gather unix group info
entries = {}

groups = ASF::Service.preload # for performance

if groups.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''
groups.keys.sort_by {|a| a.name}.each do |entry|
    next if entry.name == 'apldap' # infra team would prefer this not be publicized

    m = []
    entry.members.sort_by {|a| a.name}.each do |e|
        m << e.name
    end
    lastStamp = entry.modifyTimestamp if entry.modifyTimestamp > lastStamp
    entries[entry.name] = {
        createTimestamp: entry.createTimestamp,
        modifyTimestamp: entry.modifyTimestamp,
        roster: m 
    }
end

info = {
  # Is there a use case for the last createTimestamp ?
  lastTimestamp: lastStamp,
  services: entries,
}

public_json_output(info)
