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
#   "podling_counts": 330,
#   "status_counts": {
#     "current": 37,
#     "graduated": 224,
#     "retired": 69
#   },
#   "podling": {
#     "abdera": "graduated",
#     ....
#   }
# }

# Podling detailed file format:
# {
#   "last_updated": "2016-06-15 13:50:05 +0100",
#   "podling_counts": 330,
#   "status_counts": {
#     "current": 37,
#     "graduated": 224,
#     "retired": 69
#   },
#   "podling": {
#     ...
#     "airflow": {
#       "name": "Airflow",
#       "resource": "airflow",
#       "status": "current",
#       "startdate": "2016-03-31",
#       "description": "Airflow is a workflow automation and scheduling system.",
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

# figure out what to do to get svn updates, then uncomment this
# incubatorContent = ASF::SVN.find('incubator-content')
# incubatorPodlings = ASF::SVN.find('incubator-podlings')
# ASF::SVN.updateSimple(incubatorContent);
# ASF::SVN.updateSimple(incubatorPodlings);

pods = ASF::Podling.list.map {|podling| [podling.name, podling.status]}.to_h

mtime = ASF::Podling.mtime # must be after call to list()

status_counts = Hash.new(0)
pods.each do |_, v|
  status_counts[v] += 1
end

public_json_output(
  last_updated: mtime,
  podling_count: pods.size,
  status_counts: status_counts.sort.to_h,
  podling: pods
)

if ARGV.length == 2
  podh = ASF::Podling.list.map {|podling| [podling.name, podling.as_hash]}.to_h
  podh.each do |p| # drop empty aliases
    p[1].delete(:resourceAliases) if p[1][:resourceAliases].length == 0
    p[1].delete(:duration) # This changes every day ...
  end
  status_counts = Hash.new(0)
  podh.each do |_, v|
    status_counts[v[:status]] += 1
  end
  public_json_output_file({
    last_updated: mtime,
    podling_count: podh.size,
    status_counts: status_counts.sort.to_h,
    podling: podh
  }, ARGV[1])
end
