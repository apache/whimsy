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
#       ]
#     },
#     ...
#   },
# }
#

# ##################################################################################################
# TODO this is a preliminary version. Subject to change/removal. 
# The output format may change or may be dropped entirely - e.g. if it is merged into existing files
# ##################################################################################################

require_relative 'public_json_common'

# gather project group info
entries = {}

projects = ASF::Project.preload # for performance

if projects.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''
projects.keys.sort_by {|a| a.name}.each do |entry|
    next if entry.name == 'apldap' # infra team would prefer this not be publicized

    m = []
    entry.members.sort_by {|a| a.name}.each do |e|
        m << e.name
    end
    o = []
    entry.owners.sort_by {|a| a.name}.each do |e|
        o << e.name
    end
    lastStamp = entry.modifyTimestamp if entry.modifyTimestamp > lastStamp
    entries[entry.name] = {
        createTimestamp: entry.createTimestamp,
        modifyTimestamp: entry.modifyTimestamp,
        members: m,
        owners: o 
    }
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
      Wunderbar.warn "#{name}: unknown member uid #{id}" unless uids.include?(id)      
    end
    entry[:owners].each do |id|
      Wunderbar.warn "#{name}: unknown owner uid #{id}" unless uids.include?(id)      
    end
  end
end
