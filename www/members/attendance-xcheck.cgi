#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf'
require 'json'

# read in attendance
meetings = ASF::SVN['private/foundation/Meetings']
json = JSON.parse(IO.read "#{meetings}/attendance.json")
attend = json['matrix'].keys

# parse received info
added = Hash.new('unknown')
Dir["#{meetings}/*/memapp-received.txt"].each do |received|
  meeting = File.basename(File.dirname(received))
  next if meeting.include? 'template'
  text = File.read(received)
  list = text.scan(/<(.*)@.*>.*Yes/i) + 
    text.scan(/^(?:no\s*)*(?:yes\s+)+(\w\S*)/)
  list.flatten.each {|id| added[id] = meeting}
end

# cross check against members.txt
missing = []
ASF::Member.list.each do |id, info|
  unless attend.delete(info[:name]) or info['status']
    missing << [info[:name], added[id]]
  end
end

# produce HTML
_html do
  _style %{
    table {margin-left: 12px}
  }

  # common banner
  _a href: 'https://whimsy.apache.org/' do
    _img title: "ASF Logo", alt: "ASF Logo",
      src: "https://www.apache.org/img/asf_logo.png"
  end

  _h1_ 'members.txt vs attendance.json cross-check'

  _h2_ 'Listed as attending a members meeting, but not in members.txt'

  _ul do
    attend.sort.each do |name|
      _li name
    end
  end
  
  _h2_ 'Listed in members.txt but not listed as attending a members meeting'

  _table do
    _thead do
      _th 'name'
      _th 'date added as a member'
    end

    missing.sort.each do |name, meeting|
      next if meeting =~ /^2015/
      _tr_ do
        _td name
        _td meeting
      end
    end
  end
end
