#!/usr/bin/env ruby

# svn update and sort the members.txt file and show the differences

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

members = File.join(ASF::SVN['foundation'], 'members.txt')
cmd = %w(svn update) << members
puts cmd.join(' ')
system *cmd

source = File.read(members)
sorted = ASF::Member.sort(source)

if source == sorted
  puts 'no change'
else
  File.write(members, sorted)
  system 'svn', 'diff', members
end

