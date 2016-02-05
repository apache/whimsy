# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "groups": {
#     "abdera": {
#       "modifyTimestamp": "20111204095436Z",
#       "roster": ["uid",
#       ...
#       ]
#     },
#     ...
#   },
# }
#

require 'bundler/setup'

require_relative 'public_json_common'

require 'whimsy/asf'

# gather unix group info
entries = {}

groups = ASF::Group.preload # for performance

if groups.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''
groups.keys.sort_by {|a| a.name}.each do |entry|
    m = []
    entry.members.sort_by {|a| a.name}.each do |e|
        m << e.name
    end
    lastStamp = entry.modifyTimestamp if entry.modifyTimestamp > lastStamp
    entries[entry.name] = {
        modifyTimestamp: entry.modifyTimestamp,
        roster: m 
    }
end

info = {
  lastTimestamp: lastStamp,
  groups: entries,
}

public_json_output(info)
