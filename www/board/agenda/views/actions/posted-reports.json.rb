#
# If @path is passed, return that message body, otherwise return the
# list of reports posted to board@
#

require 'date'
require 'erb'
require 'mail'
require 'whimsy/asf/agenda'

# link to board private-arch
THREAD = "https://lists.apache.org/thread.html/"
ARCHIVE = '/srv/mail/board'

if @path and @path =~ /^\d+\/\w+$/
  mail = Mail.new(File.read(File.join(ARCHIVE, @path)))
  text = ''

  if mail.text_part
    begin
      text = mail.text_part.body.to_s.force_encoding(mail.text_part.charset)
    rescue
      text = mail.text_part.body.to_s.force_encoding(Encoding::UTF_8)
    end
  elsif mail.main_type.include? 'text'
    begin
      text = mail.body.to_s.force_encoding(mail.text_part.charset)
    rescue
      text = mail.body.to_s.force_encoding(Encoding::UTF_8)
    end
  end

  return {text: text.encode('UTF-8', invalid: :replace, undef: :replace)}
end

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
archive = Dir[File.join(ARCHIVE, previous, '*'), File.join(ARCHIVE, current ,'*')]

# select messages that have a subject line starting with [REPORT]
reports = []
archive.each do |email_path|
  email_path
  next if File.mtime(email_path) < cutoff
  next if email_path.end_with? '/index'
  message = IO.read(email_path, mode: 'rb')
  subject = message[/^Subject: .*/]
  next unless subject and subject =~ /\bREPORT\b/i
  mail = Mail.new(message.encode(message.encoding, crlf_newline: true))
  if subject and mail.subject =~ /\A[\[({]REPORT[\])}]/i
    reports << [email_path.split('/')[-2..-1].join('/'), mail]
  end
end

# Get a list of missing board reports
agendas = Dir[File.join(ASF::SVN['foundation_board'], 'board_agenda_*.txt')]
parsed = ASF::Board::Agenda.parse(IO.read(agendas.max), true)
missing = parsed.select {|item| item['missing']}.
  map {|item| item['title'].downcase}

# produce output
_ reports do |path, mail|
  _subject mail.subject
 # ERB::Util.url_encode changes space to %20 as required in the path component
  _link THREAD + ERB::Util.url_encode('<' + mail.message_id + '>')
  _path path

  subject = mail.subject.downcase
  _missing missing.any? {|title| subject =~ /\b#{Regexp.escape(title)}\b/}

  item = parsed.find {|item| subject =~ /\b#{Regexp.escape(item['title'].downcase)}\b/}
  _title item['title'] if item
end
