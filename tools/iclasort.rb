#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

iclas = File.join(ASF::SVN['officers'], 'iclas.txt')
cmd = ['svn', 'update', iclas]
puts cmd.join(' ')
system *cmd

source = File.read(iclas)
sorted = ASF::ICLA.sort(source)

if source == sorted
  puts 'no change'
else
  puts "Writing sorted file"
  File.write(iclas, sorted)
  system 'svn', 'diff', iclas
end
