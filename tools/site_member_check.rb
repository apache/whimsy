#!/usr/bin/env ruby

# @(#) DRAFT: scan members.mdtext and look for non-members (members.txt)

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
