require 'chronic'

## This is a script to generate an email for committers@apache.org from 
## an agenda file. It also requires the calendar.txt so it can determine 
## the next meeting's date and committee-info.txt so it can determine 
## who the VP is for a project.

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
agenda = Agenda.parse(File.basename(agenda_file), :quick)

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
attendance = attendance.group_by {|name, info| info[:role]}.
  map {|group, list| [group, list.map {|name, info| name}]}.to_h

# get a list of missing attachments
missing_reports = Array.new
agenda.each do |item|
  next unless item['missing']
  next if item['to'] == 'president'
  missing_reports << "Report from the Apache #{item['title']} Project" +
    "  [#{item['owner']}]"
end

##### Parse the agenda to find the data items above

# Data items from agenda
date            = nil
day             = nil
daynum          = nil
month           = nil
year            = nil
minutes         = Array.new
resolutions     = Array.new

# State variables
parsing_resolutions = false
parsing_attachment  = nil
current_attachment  = nil

File.open(agenda_file).each do |line|

  # 1: Find the date, this is used in the title and various other places
  if !date && line =~ /(\w*) (\d\d?), (\d{4})$/
    month = $1
    daynum = $2
    day = prefixNumber(daynum)
    year = $3
    date = line.strip()
    next
  end

  # 4: Get the list of listed minutes
  if line =~ /[A-Z]\. The meeting of (\w*) \d\d?, \d{4}$/
    minutes << $1
    next
  end

  # 5: Get the list of resolutions
  if line =~ /\d. Special Orders/
    parsing_resolutions = true
    next
  end
  if parsing_resolutions
    if line =~ /\d. Discussion Items/
      parsing_resolutions = false
      next
    end
    if line =~ /^\s*[A-Z]\. /
      resolutions << line.strip
      next
    end
  end

end

##### 7: Find out the date of the next board report

next_meeting = ASF::Board.nextMeeting
next_meeting = prefixNumber(next_meeting.day) + " of " + 
  next_meeting.strftime('%B')

##### 8: Find names of the VPs of TLPs in resolutions

## this does not work, since new TLPs are not yet in committee-info.txt
## instead we should parse this from the resolution

committee_file = File.join(ASF::SVN['board'], 'committee-info.txt')
parsing_projects = false
resolution_to_chair = Hash.new
File.open(committee_file).each do |line|
  if line =~ /\d. APACHE SOFTWARE FOUNDATION COMMITTEES/
    parsing_projects = true
  end
  if parsing_projects 
    if line =~ /^\s+([\w\s]+)\s\s+([^<]*)<[^>]*>\s*$/
      project = $1
      chair = $2
      project = project.strip
      resolutions.each() do |resolution|
        if resolution =~ /#{project}/
          resolution_to_chair[resolution] = chair.strip
        end
      end
    end
    if line =~ /={76}/
      parsing_projects = false
      break
    end
  end
end

##### Prepare the arrays for output
t_directors = attendance[:director].join(", ")
t_officers = attendance[:officer].join(", ")
t_guests = attendance[:guest].join(", ")
if !minutes.empty?
  t_minutes = "\nThe " + minutes.join(", ").sub(/, ([^,]*)$/, ' and \1') + " minutes were " + (minutes.length > 1 ? "all " : "") + "approved. \nMinutes will be posted to http://www.apache.org/foundation/records/minutes/\n"
else
  t_minutes = ""
end
if !missing_reports.empty?
  t_missing_reports = "The following reports were not received and are expected next month: \n\n  "
  t_missing_reports += missing_reports.join("\n  ")
  t_missing_reports += "\n"
else
  t_missing_reports = ""
end
if !resolutions.empty?
  t_resolutions = "The following resolutions were passed unanimously: \n\n"
  resolutions.each() do |resolution|
    t_resolutions += "  #{resolution}";
    # if(resolution_to_chair[resolution])
    #   t_resolutions += " (" + resolution_to_chair[resolution] +", VP)"
    # end
    t_resolutions += " (???, VP)\n"
  end
else
  t_resolutions = ""
end

##### Write the report
report = <<REPORT
PLEASE EDIT THIS, IT IS ONLY AN ESTIMATE.
From: chairman@apache.org
To: committers@apache.org
Reply-To: board@apache.org
Subject: ASF Board Meeting Summary - #{month} #{daynum}, #{year}

The #{month} board meeting took place on the #{day}.

The following directors were present:

  #{t_directors}

The following officers were present:

  #{t_officers}

The following guests were present:

  #{t_guests}
#{t_minutes}
All of the received reports to the board were approved.

#{t_missing_reports}
#{t_resolutions}
The next board meeting will be on the #{next_meeting}.
REPORT
