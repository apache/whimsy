# Reads LDAP ou=pmc,ou=committees,ou=groups,dc=apache,dc=org
# Also reads ou=projects
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
projects = ASF::Project.preload

if committees.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''

# Hack: ensure all names are represented in the hash
ASF::Committee::GUINEAPIGS.each do |pig|
  unless ASF::Committee.find(pig).modifyTimestamp # hack detect missing entry
    committees[ASF::Committee.new(pig)] = [] # add a dummy entry
  end 
end

committees.keys.sort_by {|a| a.name}.each do |entry|
    m = []
    if ASF::Committee::isGuineaPig? entry.name
        project = ASF::Project.find(entry.name)
        createTimestamp = project.createTimestamp
        modifyTimestamp = project.modifyTimestamp
        project.owners.sort_by {|a| a.name}.each do |e|
            m << e.name
        end
    else
        createTimestamp = entry.createTimestamp
        modifyTimestamp = entry.modifyTimestamp
        entry.members.sort_by {|a| a.name}.each do |e|
            m << e.name
        end
    end
    lastStamp = modifyTimestamp if modifyTimestamp > lastStamp
    entries[entry.name] = {
        createTimestamp: createTimestamp,
        modifyTimestamp: modifyTimestamp,
        roster: m 
    }
end

info = {
  # Is there a use case for the last createTimestamp ?
  lastTimestamp: lastStamp,
  committees: entries,
}

public_json_output(info)

if changed? and @old_file
  # for validating UIDs
  uids = ASF::Person.list().map(&:id)
  entries.each do |name, entry|
    entry[:roster].each do |id|
      Wunderbar.warn "#{name}: unknown uid #{id}" unless uids.include?(id)      
    end
  end
end
