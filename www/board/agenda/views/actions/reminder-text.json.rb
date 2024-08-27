# Pre-process a Mustache template, replacing the references that are fixed for a given meeting

require 'active_support/time'

raise ArgumentError, "Invalid syntax #{@reminder}" unless  @reminder =~ /\A[-\w]+\z/

# Allow override of timeZoneInfo (avoids the need to parse the last agenda)
timeZoneInfo = @tzlink
unless timeZoneInfo
  # find the latest agenda
  agenda = Dir[File.join(FOUNDATION_BOARD, 'board_agenda_*.txt')].max
  timeZoneInfo = File.read(agenda)[/Other Time Zones: (.*)/, 1]
end

# determine meeting time
meeting = ASF::Board.nextMeeting
dueDate = meeting - 7.days

# substitutable variables
# Warning: references to missing variables will be silently dropped
view = {
  project: '{{{project}}}',
  link: '{{{link}}}',
  meetingDate:  meeting.strftime('%a, %d %b %Y at %H:%M %Z'),
  month: meeting.strftime('%B'),
  year: meeting.year.to_s,
  timeZoneInfo: timeZoneInfo,
  dueDate:  dueDate.strftime("%a %b #{dueDate.day.ordinalize}"),
  agenda: meeting.strftime('https://whimsy.apache.org/board/agenda/%Y-%m-%d/')
}

# perform the substitution
AgendaTemplate.render(@reminder, view)
