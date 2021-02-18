#!/usr/bin/env ruby
PAGETITLE = "Posted Board Report Crosscheck" # Wvisible:board
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'erb'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'
require 'whimsy/asf/agenda'
require 'date'
require 'mail'

# link to board private-arch
THREAD = 'https://lists.apache.org/thread.html/'
REPORT = '[REPORT]'
MAIL_ROOT = '/srv/mail' # TODO: => Config item
MAIL_BOARD = File.join(MAIL_ROOT, 'board')

# Get a list of emails on board@ that appear to be [REPORT]*
# only look at this month's and last month's mailboxes, and within those
# only look at emails that were received in the last month.
def get_report_mails
  current = Date.today.strftime('%Y%m')
  previous = (Date.parse(current + '01')-1).strftime('%Y%m')
  cuttoff = Date.parse(previous + Date.today.strftime('%d')).to_time

  # get a list of current board messages
  archive = Dir[File.join(MAIL_BOARD, previous, '*'), File.join(MAIL_BOARD, current, '*')]

  # select messages that have a subject line starting with [REPORT]
  reports = []
  archive.each do |email|
    next if File.mtime(email) < cuttoff
    next if email.end_with? '/index'
    message = IO.read(email, mode: 'rb')
    subject = message[/^Subject: .*/]
    next unless subject and subject.upcase.include? REPORT
    mail = Mail.new(message)
    reports << mail if mail.subject.upcase.start_with? REPORT
  end
  return reports
end

report_mails = get_report_mails # Used in both _html and _json

# produce HTML output of reports, highlighting ones that have not (yet)
# been posted
_html do
  _style %{
    .missing {background-color: yellow}
  }
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "/board/agenda" => "Current Month Board Agenda",
        "/board/minutes" => "Past Minutes, Categorized",
        "https://www.apache.org/foundation/board/calendar.html" => "Past Minutes, Dated",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          This shows emails to the board@ list with reports, and cross-indexes against the actual agenda file.
          Entries in yellow were emailed, but are not yet in the agenda itself.
          Any ASF Member can assist projects by copying the report from the mail and Post Report in the proper place in the agenda.
        }
      }
    ) do
      # Get a list of missing board reports from the agenda itself
      Dir.chdir ASF::SVN['foundation_board']
      agenda = Dir['board_agenda_*.txt'].max
      parsed = ASF::Board::Agenda.parse(IO.read(agenda), true)
      missing = parsed.select {|item| item['missing']}.
        map {|item| item['title'].downcase}
      # attempt to sort reports by PMC name
      report_mails.sort_by! do |mail|
        mail.subject.downcase.sub /\sapache\s/, ' '
      end
      _h1 "Reports On board@"
      _p do
        _a 'Current board agenda', href: '/board/agenda/' +
          agenda[/\d+_\d+_\d+/].gsub('_', '-') + '/'
      end
      _table.table.table_hover.table_striped do
        _thead_ do
          _tr do
            _th 'On board@'
          end
        end
        _tbody do
          report_mails.each do |mail|
            _tr do
              _td do
              # ERB::Util.url_encode changes space to %20 as required in the path component
              href = THREAD + ERB::Util.url_encode('<' + mail.message_id + '>')
                if missing.any? {|title| mail.subject.downcase =~ /\b#{Regexp.escape(title)}\b/}
                  _td do
                    _a.missing mail.subject, href: href
                  end
                else
                  _td do
                    _a.present mail.subject, href: href
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

# produce JSON output of reports
# N.B. This is activated if the ACCEPT header references 'json'
_json do
  _ report_mails do |mail|
    _subject mail.subject
    _link THREAD + ERB::Util.url_encode('<' + mail.message_id + '>')

    subject = mail.subject.downcase
    _missing missing.any? {|title| subject =~ /\b#{Regexp.escape(title)}\b/}

    item = parsed.find {|item| subject =~ /\b#{Regexp.escape(item['title'].downcase)}\b/}
    _title item['title'] if item
  end
end
