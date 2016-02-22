#!/usr/bin/ruby1.9.1
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf'
require 'wunderbar'
require 'date'
require 'json'

# separator / is added when link is generated
ROSTER = "https://whimsy.apache.org/roster/committer"

# locate and read the attendance file
MEETINGS = ASF::SVN['private/foundation/Meetings']
attendance = JSON.parse(IO.read("#{MEETINGS}/attendance.json"))

# extract and format dates
dates = attendance['dates'].sort.
  map {|date| Date.parse(date).strftime('%Y-%b-%d')}

# compute mappings of names to ids
members = ASF::Member.list
active = members.select {|id, data| not data['status']}
nameMap = Hash[members.map {|id, data| [id, data[:name]]}]
idMap = Hash[nameMap.to_a.map(&:reverse)]

# analyze attendance
matrix = attendance['matrix'].map do |name, meetings|
  id = idMap[name]
  next unless id
  data = meetings.sort.reverse.map(&:last)
  missed = (data.index {|datum| datum != '-'} || data.length)
 
  [id, name, missed]
end

# produce HTML
_html do
  # common banner
  _a href: 'https://whimsy.apache.org/' do
    _img title: "ASF Logo", alt: "ASF Logo",
      src: "https://www.apache.org/img/asf_logo.png"
  end

  _h1 'Non-participating active members'

  @meetingsMissed = (@meetingsMissed || 5).to_i

  # selection
  _form_ do
    _span "List of members that have not participated, starting with the "
    _select name: 'meetingsMissed', onChange: 'this.form.submit()' do
      dates.reverse.each_with_index do |name, i|
        _option name, value: i+1, selected: (i+1 == @meetingsMissed)
      end
    end
    _span "meeting."
  end

  count = 0
  _table do
    _tr do
      _th 'Name'
      _th 'Last participated'
    end

    matrix.each do |id, name, missed|
      next unless id
    
      if missed > @meetingsMissed
        _tr_ do
          _td! {_a nameMap[id], href: "#{ROSTER}/#{id}"}
          _td dates[-missed]
        end
        count += 1
      end
    end
  end

  _p "Count: #{count}"
end

_json do
  meetingsMissed = (@meetingsMissed || 5).to_i
  inactive = matrix.select {|id, name, missed| id and missed > meetingsMissed}
  Hash[inactive.map {|id, name, missed| 
    [id, {name: name, missed: missed-1, status: 'no response yet'}]
  }]
end
