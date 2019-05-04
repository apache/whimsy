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

require 'chronic'

## This is a script to generate an email for committers@apache.org

# load agenda and minutes
board_svn = ASF::SVN['foundation_board']
minutes_file = File.join(AGENDA_WORK, "board_minutes_#@date.yml").untaint
agenda_file = File.join(board_svn, "board_agenda_#@date.txt").untaint
minutes = YAML.load_file(minutes_file) rescue {}
agenda = Agenda.parse(File.basename(agenda_file), :full)

# extract attendance from minutes and people from agenda
attendance = Array(minutes['attendance']).select {|name, info| info[:present]}.
  sort_by {|name, info| info[:sortName]}
people = agenda[1]['people'].values

# merge role from agenda into attendance
attendance.each do |name, info|
  person = people.find {|person| person[:name] == name}
  info[:role] = person ? person[:role] : :guest
end

# group attendance by role (directors, officers, guests)
@attendance = attendance.group_by {|name, info| info[:role]}.
  map {|group, list| [group, list.map {|name, info| name}]}.to_h

# get a list of missing attachments
@missing_reports = Array.new
agenda.each do |item|
  next unless item['missing']
  next if item['to'] == 'president'
  @missing_reports << item
end

# extract list of rejected reports
@rejected = Array(minutes[:rejected])

# extract date of the meeting
@date = Time.at(agenda[0]['timestamp']/1000)

# get list of minutes
@approved_minutes = Array.new
@other_minutes = Array.new
agenda.each do |item|
  next unless item[:attach] =~ /^3[A-Z]/
  month = item['title'].split(' ').first
  if minutes[item['title']] == 'approved'
    @approved_minutes << month
  else
    @other_minutes << [ month, minutes[item['title']] || 'tabled' ]
  end
end

# get list of resolutions
@approved_resolutions = Array.new
@other_resolutions = Array.new
agenda.each do |item|
  next unless item[:attach] =~ /^7[A-Z]/
  title = item['fulltitle'] || item['title']
  if minutes[item['title']] == 'unanimous'
    chair = item['chair']
    title += " (#{item['people'][chair][:name]}, VP)" if chair
    @approved_resolutions << title
  else
    @other_resolutions << [item['fulltitle'], minutes[item['title']]||'tabled']
  end
end

# Find out the date of the next board report
next_meeting = ASF::Board.nextMeeting
@next_meeting = next_meeting.day.ordinalize + " of " + 
  next_meeting.strftime('%B')

# author of the email
sender = ASF::Person.find(env.user || ENV['USER'])
@from = "#{sender.public_name.inspect} <#{sender.id}@apache.org>"

##### Write the report
template = File.read('templates/committers_report.text.erb').untaint
Erubis::Eruby.new(template).result(binding)
