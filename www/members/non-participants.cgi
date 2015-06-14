#!/usr/bin/ruby1.9.1
require 'whimsy/asf'
require 'wunderbar'
require 'date'

ROSTER = "https://whimsy.apache.org/roster/committer/"

# locate and read the attendance file
MEETINGS = ASF::SVN['private/foundation/Meetings']
attendance = IO.read("#{MEETINGS}/attendance.txt")

# scan the headings, extract column information
headings = attendance[/^(\s+\d+)+/]
col = 0
cols = headings.scan(/(\s+)(\d+)/).map {|spaces, date|
  col += spaces.length
  Range.new(col, col+=date.length)
}

# column information for the member name
nameField =  0...cols.first.begin

# extract and format dates
dates = cols.map {|range| headings[range]}.
  map {|date| Date.parse(date).strftime('%Y-%b-%d')}

# compute mappings of names to ids
active = ASF::Member.list.select {|id, data| not data['status']}
nameMap = Hash[active.map {|id, data| [id, data[:text].split("\n").first]}]
idMap = Hash[nameMap.map {|id, name| [name.gsub(/[^\x20-\x7F]/, ''), id]}]

# handle cases where names in attendance don't match members.txt
idMap["Antonio Gallardo Rivera"] = "antonio"
# idMap["Astrid Keler"] = ?
# idMap["Astrid Stolper"] = ?
idMap["Craig Russell"] = 'clr'
idMap["Donald A. Ball Jr."] = 'balld'
idMap["Maisonobe Luc"] = 'luc'
idMap["Noirin Shirley"] = 'noirinp'
idMap["Reto Bachmann-Gmr"] = 'reto'
idMap["Robertus W.A.M. Huijben (\"Bert\")"] = 'rhuijben'
idMap["Thomas Fischer"] = 'tfischer'
idMap["Wilfredo Sanchez"] = 'wsanchez'
# idMap["William Stoddard"] = 'stoddard'

# produce HTML
_html do
  _h1 'Non-participating active members'

  @meetingsMissed = (@meetingsMissed || 7).to_i

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

    attendance.scan(/^[(A-Za-z].*\]\s*$/).each do |line|
      name = line[nameField].strip
      id = idMap[name]
      next unless id
      data = cols.map {|field| line[field].strip}.reverse
      missed = data.index {|datum| datum != '-'} + 1
    
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
