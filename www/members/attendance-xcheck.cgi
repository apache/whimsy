#!/usr/bin/ruby1.9.1
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf'
require 'json'

# read in attendance
meetings = ASF::SVN['private/foundation/Meetings']
json = JSON.parse(IO.read "#{meetings}/attendance.json")
attend = json['matrix'].keys

# cross check against members.txt
missing = []
ASF::Member.list.each do |id, info|
  missing << info[:name] unless attend.delete info[:name] or info['status']
end
missing.delete ''

# produce HTML
_html do
  _h1_ 'members.txt vs attendance.json cross-check'

  _h2_ 'Listed as attending a members meeting, but not in members.txt'

  _ul do
    attend.sort.each do |name|
      _li name
    end
  end
  
  _h2_ 'Listed in members.txt but not listed as attending a members meeting'

  _ul do
    missing.sort.each do |name|
      _li name
    end
  end
end
