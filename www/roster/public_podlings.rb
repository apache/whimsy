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

# Reads the incubator podlings.xml file and generates a summary status file
# If a second file name is provided, also generates a detailed file with all the fields
#
# Podling status file format:
# {
#   "last_updated": "2016-06-15 13:50:05 +0100",
#   "podling": {
#     "abdera": "graduated",
#     ....
#   }
# }

# Podling detailed file format:
# {
#   "last_updated": "2016-06-15 13:50:05 +0100",
#   "podling": {
#     ...
#     "airflow": {
#       "name": "Airflow",
#       "resource": "airflow",
#       "status": "current",
#       "startdate": "2016-03-31",
#       "description": "Airflow is a workflow automation and scheduling system that can be used to author and manage data pipelines.",
#       "mentors": [
#         "cnauroth",
#         "hitesh",
#         "jghoman"
#       ],
#       "reporting": { # PROVISIONAL FORMAT
#          "group": "1",
#          "text": "May, June, July",
#          "monthly": [
#            "May",
#            "June",
#            "July"
#          ]
#         },
#       "champion": "criccomini",
#       "resource": "airflow",
#       "resourceAliases": [
#
#       ]
#     },
#     "accumulo": {
#       ...
#     },
#     ...
#   }
# }
#
# =====================================================
# N.B. The "reporting" hash format is subject to change
# =====================================================

require_relative 'public_json_common'

pods = Hash[ASF::Podling.list.map {|podling| [podling.name, podling.status]}]

mtime =  ASF::Podling.mtime # must be after call to list()

public_json_output(
 last_updated: mtime,
 podling: pods
)

if ARGV.length == 2
  podh = Hash[ASF::Podling.list.map {|podling| [podling.name, podling.as_hash]}]
  podh.each do |p| # drop empty aliases
    p[1].delete(:resourceAliases) if p[1][:resourceAliases].length == 0
    p[1].delete(:duration) # This changes every day ...
  end
  public_json_output_file({
    last_updated: mtime,
    podling: podh    
  }, ARGV[1])
end
