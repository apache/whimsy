require 'chronic'

## This is a script to generate an email for committers@apache.org

# Add the right prefix to a number
def prefixNumber(number) 
  if number % 10 == 1
    number.to_s + "st"
  elsif number % 10 == 2
    number.to_s + "nd"
  else
    number.to_s + "th"
  end
end

# load agenda and minutes
board_svn = ASF::SVN['foundation_board']
minutes_file = Dir[File.join(AGENDA_WORK, 'board_minutes_*.yml')].sort.
  last.untaint
agenda_file = File.join(board_svn, File.basename(minutes_file).
  sub('_minutes_', '_agenda_').sub('.yml', '.txt'))
minutes = YAML.load_file(minutes_file)
agenda = Agenda.parse(File.basename(agenda_file), :full)

# extract attendance from minutes and people from agenda
attendance = minutes['attendance'].select {|name, info| info[:present]}.
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

# extract date of the meeting
@date = Time.at(agenda[0]['timestamp']/1000)

# get list of minutes
approved_minutes = Array.new
other_minutes = Array.new
agenda.each do |item|
  next unless item[:attach] =~ /^3[A-Z]/
  month = item['title'].split(' ').first
  if minutes[item['title']] == 'approved'
    approved_minutes << month
  else
    other_minutes << "The #{month} minutes were #{minutes[item['title']]}."
  end
end

# get list of resolutions
approved_resolutions = Array.new
other_resolutions = Array.new
agenda.each do |item|
  next unless item[:attach] =~ /^7[A-Z]/
  title = item['fulltitle']
  if minutes[item['title']] == 'unanimous'
    chair = item['chair']
    title += " (#{item['people'][chair][:name]}, VP)" if chair
    approved_resolutions << title
  else
    other_resolutions << "The #{item['fulltitle']} resolution was #{minutes[item['title']]}."
  end
end

##### 7: Find out the date of the next board report

next_meeting = ASF::Board.nextMeeting
@next_meeting = prefixNumber(next_meeting.day) + " of " + 
  next_meeting.strftime('%B')

if !approved_minutes.empty?
  @minutes = "\nThe " + approved_minutes.join(", ").sub(/, ([^,]*)$/, ' and \1') + " minutes were " + (approved_minutes.length > 1 ? "all " : "") + "approved. \nMinutes will be posted to http://www.apache.org/foundation/records/minutes/\n"
else
  @minutes = ""
end

if !other_minutes.empty?
  @minutes += other_minutes.join("\n") + "\n"
end

if !approved_resolutions.empty?
  @resolutions = "The following resolutions were passed unanimously: \n\n"
  approved_resolutions.each() do |resolution|
    @resolutions += "  #{resolution}\n";
  end
else
  @resolutions = ""
end

if !other_resolutions.empty?
  @resolutions += "\n" + other_resolutions.join("\n") + "\n"
end

##### Write the report
template = <<REPORT
PLEASE EDIT THIS, IT IS ONLY AN ESTIMATE.
From: chairman@apache.org
To: committers@apache.org
Reply-To: board@apache.org
Subject: ASF Board Meeting Summary - #{@date.strftime('%B %d, %Y')}

The #{@date.strftime('%B')} board meeting took place on the #{prefixNumber(@date.day)}.

The following directors were present:

  <%= @attendance[:director].join(", ") %>

The following officers were present:

  <%= @attendance[:officer].join(", ") %>

The following guests were present:

  <%= @attendance[:guest].join(", ") %>
#{@minutes}
All of the received reports to the board were approved.

<% unless @missing_reports.empty? %>
The following reports were not received and are expected next month:

<% @missing_reports.each do |report| %>
  Report from the Apache <%= report['title'] %> Project [<%= report['owner'] %>]
<% end %>

<% end %>
#{@resolutions}
The next board meeting will be on the #{@next_meeting}.
REPORT

Erubis::Eruby.new(template).result(binding)
