#!/usr/bin/env ruby

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'date'
require 'mail'
require 'wunderbar'
require 'whimsy/asf/agenda'

# link to board private-arch
THREAD = "https://lists.apache.org/thread.html/"

# only look at this month's and last month's mailboxes, and within those
# only look at emails that were received in the last month.
current = Date.today.strftime('%Y%m')
previous = (Date.parse(current + '01')-1).strftime('%Y%m')
cuttoff = Date.parse(previous + Date.today.strftime('%d')).to_time

# get a list of current board messages
archive = Dir["/srv/mail/board/#{previous}/*", "/srv/mail/board/#{current}/*"]

# select messages that have a subject line starting with [REPORT]
reports = []
archive.each do |email|
  next if File.mtime(email) < cuttoff
  next if email.end_with? '/index'
  message = IO.read(email, mode: 'rb')
  subject = message[/^Subject: .*/]
  next unless subject and subject.upcase.include? "[REPORT]"
  mail = Mail.new(message)
  reports << mail if mail.subject.upcase.start_with? "[REPORT]"
end

# Get a list of missing board reports
Dir.chdir ASF::SVN['foundation_board']
agenda = Dir['board_agenda_*.txt'].sort.last
parsed = ASF::Board::Agenda.parse(IO.read(agenda), true)
missing = parsed.select {|item| item['missing']}.
  map {|item| item['title'].downcase}

# produce HTML output of reports, highlighting ones that have not (yet)
# been posted
_html do
  _style %{
    .missing {background-color: yellow}
  }

  _h1 "Posted PMC reports"

  _a agenda, href: '/board/agenda/' +
    agenda[/\d+_\d+_\d+/].gsub('_', '-') + '/'

  # attempt to sort reports by PMC name
  reports.sort_by! do |mail| 
    mail.subject.downcase.sub /\sapache\s/, ' '
  end

  # output an unordered list of subjects linked to the message archive
  _ul reports do |mail|
    _li do
      href = THREAD + URI.escape('<' + mail.message_id + '>')

      if missing.any? {|title| mail.subject.downcase =~ /\b#{title}\b/}
        _a.missing mail.subject, href: href
      else
        _a.present mail.subject, href: href
      end
    end
  end
end

# produce JSON output of reports
_json do
  _ reports do |mail|
    _subject mail.subject
    _link THREAD + URI.escape('<' + mail.message_id + '>')

    subject = mail.subject.downcase
    _missing missing.any? {|title| subject =~ /\b#{title}\b/}

    item = parsed.find {|item| subject =~ /\b#{item['title'].downcase}\b/}
    _title item['title'] if item
  end
end
