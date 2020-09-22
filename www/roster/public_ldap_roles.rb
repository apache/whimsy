# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "rolegroups": {
#     "committers": {
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

# gather service group info
entries = {}

groups = ASF::RoleGroup.preload # for performance

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
  rolegroups: entries,
}

public_json_output(info)

# special check for committers group which exists in two places currently
role_group = entries['committers']
if role_group
  unix_group = ASF::Group['committers']
  if unix_group
    commit_unix = unix_group.members.map(&:id)
    commit_role = role_group[:roster]
    unless commit_role == commit_unix
      diff = commit_role - commit_unix
      Wunderbar.warn "ASF::RoleGroup['committers'] contains #{diff} but ASF::Group['committers'] does not" if diff.size > 0
      diff = commit_unix - commit_role
      Wunderbar.warn "ASF::Group['committers']     contains #{diff} but ASF::RoleGroup['committers'] does not" if diff.size > 0
    end
  end
end

if changed? and @old_file
  # for validating UIDs
  uids = ASF::Person.list().map(&:id)
  entries.each do |name, entry|
    entry[:roster].each do |id|
      Wunderbar.warn "#{name}: unknown uid '#{id}'" unless uids.include?(id)
    end
  end
end
