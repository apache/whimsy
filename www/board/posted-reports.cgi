#!/usr/bin/ruby1.9.1

require 'mail'
require 'wunderbar'
require 'whimsy/asf/agenda'

# link to board private-arch
MBOX = "https://mail-search.apache.org/members/private-arch/board"

# get a list of current board messages
archive = Dir['/home/apmail/board/archive/*/*']

# select messages that have a subject line starting with [REPORT]
reports = []
archive.each do |email|
  next if email.end_with? '/index'
  message = IO.read(email, mode: 'rb')
  subject = message[/^Subject: .*/]
  next unless subject.include? "[REPORT]"
  mail = Mail.new(message)
  reports << mail if mail.subject.start_with? "[REPORT]"
end

# Get a list of missing board reports
Dir.chdir ASF::SVN['private/foundation/board']
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

  _a agenda, href: 'https://whimsy.apache.org/board/agenda/' +
    agenda[/\d+_\d+_\d+/].gsub('_', '-') + '/'

  # attempt to sort reports by PMC name
  reports.sort_by! do |mail| 
    mail.subject.downcase.sub /\sapache\s/, ' '
  end

  # output an unordered list of subjects linked to the message archive
  _ul reports do |mail|
    _li do
      mbox = mail.date.strftime("#{MBOX}/%Y%m.mbox/")
      href = mbox + URI.escape('<' + mail.message_id + '>')

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
    mbox = mail.date.strftime("#{MBOX}/%Y%m.mbox/")

    _subject mail.subject
    _link mbox + URI.escape('<' + mail.message_id + '>')

    subject = mail.subject.downcase
    _missing missing.any? {|title| subject =~ /\b#{title}\b/}

    item = parsed.find {|item| subject =~ /\b#{item['title'].downcase}\b/}
    _title item['title'] if item
  end
end
