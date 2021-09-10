# Reads LDAP ou=auth,ou=groups,dc=apache,dc=org
# Creates JSON output with the following format:
#
# {
# "lastTimestamp": "20160807004722Z",
# "auth_count": 123,
# "roster_counts": {
#   "accounting": 3,
#   "apachecon": 34,
#    ...
# }
# "auth": {
#   "accounting": {
#     "createTimestamp": "20160802141719Z",
#     "modifyTimestamp": "20160806162424Z",
#     "roster_count": 123,
#     "roster": [
#     ...
#     ]
#   },
#   "apachecon": {
#     "createTimestamp": "20160802141719Z",
#     "modifyTimestamp": "20160802141719Z",
#     "roster_count": 123,
#     "roster": [
#     ...
#   },
# }
#

require_relative 'public_json_common'

# gather auth group info
entries = {}

groups = ASF::AuthGroup.preload # for performance

if groups.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''
roster_counts = Hash.new(0)
groups.keys.sort_by(&:name).each do |entry|
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
  # Summarise the counts in the following entries for ease of access
  auth_count: entries.size,
  roster_counts: roster_counts,
  auth: entries,
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
