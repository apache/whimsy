#!/usr/bin/env ruby

# @(#) DRAFT: scan members.mdtext and look for non-members (members.txt)

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'strscan'

members = ASF::Member.list.keys

MEMBERS = 'apache/www-site/main/content/foundation/members.md'

code, contents = ASF::Git.github(MEMBERS)
raise "Could not read #{MEMBERS}, error: #{code}" unless code == '200'

# # Members of The Apache Software Foundation #
#
# N.B. the listing below is optional; there is a separate summary of  [members](http://home.apache.org/committers-by-project.html#member)
#
# | Id | Name | Projects |
# |^---|------|----------|
# | aadamchik | Andrei Adamchik |

s = StringScanner.new(contents)
s.skip_until(/\| Id \| Name \| Projects \|\n/)
s.skip_until(/\n/)
loop do
  s.scan(/\| (\S+) \|.*?$/)
  id = s[1] or break
  puts id unless members.include? id
  s.skip_until(/\n/)
end
