##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

# Reads LDAP ou=projects and committee-info
#
# Previously read LDAP ou=pmc,ou=committees,ou=groups,dc=apache,dc=org
# but this is deprecated.
# The output is intended to include the same entries as before;
# as such it includes tac and security even though they are not PMCs
#
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

projects = ASF::Project.preload
# which projects should be in the committees file?
# The output previously included all entries in the LDAP committee group,
# i.e. tac and security as well as all valid PMCs
# TODO perhaps drop these?
pmcs = ASF::Committee.pmcs.map(&:name) + ['tac', 'security']

if projects.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

lastStamp = ''

projects.keys.sort_by {|a| a.name}.each do |project|
  next unless pmcs.include? project.name
  m = []
  createTimestamp = project.createTimestamp
  modifyTimestamp = project.modifyTimestamp
  project.owners.sort_by {|a| a.name}.each do |e|
      m << e.name
  end
  lastStamp = modifyTimestamp if modifyTimestamp > lastStamp
  entries[project.name] = {
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
