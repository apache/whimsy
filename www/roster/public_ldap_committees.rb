# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "committees": {
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

require_relative 'public_json_common'

# gather committee info
entries = {}

committees = ASF::Committee.preload # for performance

if committees.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''
committees.keys.sort_by {|a| a.name}.each do |entry|
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
  committees: entries,
}

public_json_output(info)
