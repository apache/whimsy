require 'active_support/time'
require 'active_support/core_ext/integer/inflections.rb'

# read template for the reminders
template = File.read("data/#@reminder.txt")

# find the latest agenda
agenda = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort.last

# determine meeting time
us_pacific = TZInfo::Timezone.get('US/Pacific')
meeting = Time.new(*agenda[/\d[\d_]+/].split('_').map(&:to_i), 10, 30)
meeting = us_pacific.local_to_utc(meeting).in_time_zone(us_pacific)
dueDate = meeting - 7.days

# substitutable variables
vars = {
  meetingDate:  meeting.strftime("%a, %d %b %Y at %H:%M %Z"),
  month: meeting.strftime("%B"),
  year: meeting.year.to_s,
  dueDate:  dueDate.strftime("%a %b #{dueDate.day.ordinalize}"),
  agenda: meeting.strftime("https://whimsy.apache.org/board/agenda/%Y-%m-%d/")
}

# perform the substitution
vars.each {|var, value| template.gsub! "[#{var}]", value}

# extract subject
subject = template[/Subject: (.*)/, 1]
template[/Subject: .*\s+/] = ''

# return results
{subject: subject, body: template}
