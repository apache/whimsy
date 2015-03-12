#!/usr/bin/ruby1.9.1

require 'mail'
require 'wunderbar'
require 'whimsy/asf/agenda'

# link to board private-arch
MBOX = "https://mail-search.apache.org/members/private-arch/board/201503.mbox/"

# get a list of current board messages
board = IO.read('/home/apmail/board/current', mode: 'rb')
board = board.split(/^From .*\n/)
board.shift

# select messages that have a subject line starting with [REPORT]
reports = []
board.each do |message|
  subject = message[/^Subject: .*/]
  next unless subject.include? "[REPORT]"
  mail = Mail.new(message)
  reports << mail if mail.subject.start_with? "[REPORT]"
end

# Get a list of missing board reports
Dir.chdir ASF::SVN['private/foundation/board']
agenda = Dir['board_agenda_*.txt'].sort.last
missing = ASF::Board::Agenda.parse(IO.read(agenda), true).
  select {|item| item['missing']}.
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
      href = MBOX + URI.escape('<' + mail.message_id + '>')

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
    _link MBOX + URI.escape('<' + mail.message_id + '>')
    _missing missing.any? {|title| mail.subject.downcase =~ /\b#{title}\b/}
  end
end
