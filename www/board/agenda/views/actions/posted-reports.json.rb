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
# If @path is passed, return that message body, otherwise return the
# list of reports posted to board@
#

require 'date'
require 'mail'
require 'whimsy/asf/agenda'

# link to board private-arch
THREAD = "https://lists.apache.org/thread.html/"
ARCHIVE = '/srv/mail/board'

if @path and @path =~ /^\d+\/\w+$/
  mail = Mail.new(File.read(File.join(ARCHIVE, @path)))
  if mail.text_part
    begin
      text = mail.text_part.body.to_s.force_encoding(mail.text_part.charset)
    rescue
      text = mail.text_part.body.to_s.force_encoding(Encoding::UTF_8)
    end
      
    return {text: text.encode('UTF-8', invalid: :replace, undef: :replace)}

  else
    return {text: ''}
  end
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
archive = Dir["#{ARCHIVE}/#{previous}/*", "/srv/mail/board/#{current}/*"]

# select messages that have a subject line starting with [REPORT]
reports = []
archive.each do |email_path|
  email_path.untaint
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
parsed = ASF::Board::Agenda.parse(IO.read(agendas.sort.last.untaint), true)
missing = parsed.select {|item| item['missing']}.
  map {|item| item['title'].downcase}

# produce output
_ reports do |path, mail|
  _subject mail.subject
  _link THREAD + URI.escape('<' + mail.message_id + '>')
  _path path

  subject = mail.subject.downcase
  _missing missing.any? {|title| subject =~ /\b#{title}\b/}

  item = parsed.find {|item| subject =~ /\b#{item['title'].downcase}\b/}
  _title item['title'] if item
end
