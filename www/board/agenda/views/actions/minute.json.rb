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

#
# Add secretarial minutes to a given agenda item
#

@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = "#{AGENDA_WORK}/#{@minutes.sub('.txt', '.yml')}"
minutes_file.untaint if @minutes =~ /^board_minutes_\d+-\d+-\d+\.txt$/

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

if @action == 'timestamp'

  timestamp = Time.now

  # date = @agenda[/\d+_\d+_\d+/].gsub('_', '-')
  # zone = Time.parse("#{date} PST").dst? ? '-07:00' : '-08:00'
  # workaround for broken tzinfo on whimsy
  month = @agenda[/\d+_(\d+)_\d+/, 1].to_i
  zone = ((2..9).include? month) ? '-07:00' : '-08:00'
  @text = timestamp.getlocal(zone).strftime('%-l:%M')

  if @title == 'Call to order'
    minutes['started']  = timestamp.gmtime.to_f * 1000
  elsif @title == 'Adjournment'
    minutes['complete'] = timestamp.gmtime.to_f * 1000
  end

elsif @action == 'attendance'

  # lazily initialize attendance information
  attendance = minutes['attendance'] ||= {}
  agenda = Agenda.parse @agenda, :quick
  people = agenda.find {|item| item['title'] == 'Roll Call'}['people']
  people.each {|id, person| attendance[person[:name]] ||= {present: false}}

  # update attendance records for attendee
  attendance[@name] = {
    id: @id,
    present: @present, 
    notes: (@notes and not @notes.empty?) ? " - #@notes" : nil,
    member: ASF::Person.find(@id).asf_member?,
    sortName: @name.split(' ').rotate(-1).join(' ')
  }

  # build minutes for roll call
  @text = "Directors Present:\n\n"
  people.each do |id, person|
    next unless person[:role] == :director
    name = person[:name]
    next unless attendance[name][:present]
    @text += "  #{name}#{attendance[name][:notes]}\n"
  end

  @text += "\nDirectors Absent:\n\n"
  first = true
  people.each do |id, person|
    next unless person[:role] == :director
    name = person[:name]
    next if attendance[name][:present]
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end
  @text += "  none\n" if first

  first = true
  people.each do |id, person|
    next unless person[:role] == :officer
    name = person[:name]
    next unless attendance[name][:present]
    @text += "\nExecutive Officers Present:\n\n" if first
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end

  @text += "\nExecutive Officers Absent:\n\n"
  first = true
  people.each do |id, person|
    next unless person[:role] == :officer
    name = person[:name]
    next if attendance[name][:present]
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end
  @text += "  none\n" if first

  first = true
  attendance.to_a.sort.each do |name, records|
    next unless records[:present]
    person = people.find {|id, person| person[:name] == name}
    next if person and not person.last[:role] == :guest
    @text += "\nGuests:\n\n" if first
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end

  @title = 'Roll Call'
else
  @text = @text.reflow(0, 78)
end

if @text and not @text.empty?
  minutes[@title] = @text
else
  minutes.delete @title
  minutes.delete 'started'  if @title == 'Call to order'
  minutes.delete 'complete' if @title == 'Adjournment'
end

if @reject
  minutes[:rejected] ||= []
  minutes[:rejected] << @title unless minutes[:rejected].include? @title
elsif minutes[:rejected]
  minutes[:rejected].delete @title
end

File.write minutes_file, YAML.dump(minutes)

minutes
