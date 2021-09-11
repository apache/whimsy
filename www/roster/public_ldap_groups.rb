# Reads LDAP ou=groups,dc=apache,dc=org which is still used for some groups:
# - apsite
# - committers (this is also in ou=roles)
# - members
#
# The contents cannot be used to determine LDAP group membership
#
# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "group_count": 123,
#   "roster_counts": {
#     "apsite": 123,
#     ///
#   },
#   "groups": {
#     "apsite": {
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

entries = {}

groups = ASF::Group.preload # for performance
lastStamp = ''

roster_counts = Hash.new(0)
groups.sort_by {|g, _| g.name}.each do |group, _|
  m = []
  createTimestamp = group.createTimestamp
  modifyTimestamp = group.modifyTimestamp
  group.members.sort_by(&:name).each do |e|
    m << e.name
  end
  lastStamp = modifyTimestamp if modifyTimestamp > lastStamp
  entries[group.name] = {
    createTimestamp: createTimestamp,
    modifyTimestamp: modifyTimestamp,
    roster_count: m.size,
    roster: m
  }
  roster_counts[group.name] = m.size
end

info = {
  # Is there a use case for the last createTimestamp ?
  lastTimestamp: lastStamp,
  group_count: entries.size,
  roster_counts: roster_counts,
  groups: entries,
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
