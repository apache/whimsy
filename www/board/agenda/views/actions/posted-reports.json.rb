#
# List of reports posted to board@
#

require 'date'
require 'mail'
require 'whimsy/asf/agenda'

# link to board private-arch
THREAD = "https://lists.apache.org/thread.html/"

# only look at this month's and last month's mailboxes, and within those
# only look at emails that were received since the previous board meeting.
current = Date.today.strftime('%Y%m')
previous = (Date.parse(current + '01')-1).strftime('%Y%m')
last_meeting = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort[-2]
if last_meeting
  cutoff = (Date.parse(last_meeting[/\d[_\d]+/].gsub('_', '-'))+1).to_time
else
  cutoff = (Date.today << 1).to_time
end

# get a list of current board messages
archive = Dir["/srv/mail/board/#{previous}/*", "/srv/mail/board/#{current}/*"]

# select messages that have a subject line starting with [REPORT]
reports = []
archive.each do |email|
  email.untaint
  next if File.mtime(email) < cutoff
  next if email.end_with? '/index'
  message = IO.read(email, mode: 'rb')
  subject = message[/^Subject: .*/]
  next unless subject and subject.upcase.include? "[REPORT]"
  mail = Mail.new(message.encode(message.encoding, crlf_newline: true))
  reports << mail if subject and mail.subject.upcase.start_with? "[REPORT]"
end

# Get a list of missing board reports
agendas = Dir["#{ASF::SVN['private/foundation/board']}/board_agenda_*.txt"]
parsed = ASF::Board::Agenda.parse(IO.read(agendas.sort.last.untaint), true)
missing = parsed.select {|item| item['missing']}.
  map {|item| item['title'].downcase}

# produce output
_ reports do |mail|
  _subject mail.subject
  _link THREAD + URI.escape('<' + mail.message_id + '>')

  subject = mail.subject.downcase
  _missing missing.any? {|title| subject =~ /\b#{title}\b/}

  item = parsed.find {|item| subject =~ /\b#{item['title'].downcase}\b/}
  _title item['title'] if item
end
