require 'active_support/time'

# read template for the reminders
@reminder.untaint if @reminder =~ /^reminder\d$/
@reminder.untaint if @reminder =~ /^non-responsive$/
template = File.read("#{FOUNDATION_BOARD}/templates/#@reminder.mustache")

# find the latest agenda
agenda = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort.last.untaint

# determine meeting time
meeting = ASF::Board.nextMeeting
dueDate = meeting - 7.days

# substitutable variables
view = {
  project: '{{{project}}}',
  link: '{{{link}}}',
  meetingDate:  meeting.strftime("%a, %d %b %Y at %H:%M %Z"),
  month: meeting.strftime("%B"),
  year: meeting.year.to_s,
  timeZoneInfo: File.read(agenda)[/Other Time Zones: (.*)/, 1],
  dueDate:  dueDate.strftime("%a %b #{dueDate.day.ordinalize}"),
  agenda: meeting.strftime("https://whimsy.apache.org/board/agenda/%Y-%m-%d/")
}

# perform the substitution
template = Mustache.render(template, view)

# extract subject
subject = template[/Subject: (.*)/, 1]
template[/Subject: .*\s+/] = ''

# return results
{subject: subject, body: template}
