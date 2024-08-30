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

status = ASF::Member.status
emeritus = ASF::Member.emeritus
current = ASF::Member.current

MEMBERS = 'apache/www-site/main/content/foundation/members.md'

file = ARGV.shift # Override for local testing
if file
  puts "Reading #{file}"
  contents = File.read(file)
else
  puts 'Fetching members.md'
  code, contents = ASF::Git.github(MEMBERS)
  raise "Could not read #{MEMBERS}, error: #{code}" unless code == '200'
end

# # Members of The Apache Software Foundation #
#
# N.B. the listing below is optional; there is a separate summary of  [members](http://home.apache.org/committers-by-project.html#member)
#
# | Id | Name | Projects |
# |^---|------|----------|
# | id | Public Name |

puts 'Checking member list'
puts '===================='

s = StringScanner.new(contents)
s.skip_until(/\| Id \| Name \| Projects \|\n/)
s.skip_until(/\n/)
prev = nil # for context on error
loop do
  s.scan(/\| (\S+) \|.*?$/)
  id = s[1]
  unless current.include? id
    puts "#{id}: #{status[id] || 'unknown status'}"
    puts "Previous id: #{prev}" unless id
  end
  prev = id
  s.skip_until(/\n/)
  break if s.match? %r{^\s*$|^##} # blank line or next section
end


# ## Emeritus Members of The Apache Software Foundation
#
# | Id | Name |
# |----|------|
# | id or ? | Public Name |

puts ''

puts 'Checking Emeritus list'
puts '======================'

s.skip_until(/\| Id \| Name \|\n/)
s.skip_until(/\n/)
loop do
  s.scan(/\| (\S+) \|.*?$/)
  id = s[1] or break
  unless id == '?'
    unless emeritus.include?(id)
      puts "#{id} #{status[id] || current.include?(id) ? 'Current member' : 'unknown id'}"
    end
  end
  s.skip_until(/\n/)
end
