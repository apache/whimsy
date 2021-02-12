#!/usr/bin/env ruby
PAGETITLE = "New Member nominations cross-check" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'erb'
require 'mail'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require_relative 'meeting-util'

# link to members private-arch
MBOX = 'https://mail-search.apache.org/members/private-arch/members/'

# link to roster page
ROSTER = '/roster/committer'
MEETINGS = ASF::SVN['Meetings']

# Encapsulate gathering data to improve error processing
def setup_data(cur_mtg_dir)
  # get a list of current year's members@ emails
  year = Time.new.year.to_s
  archive = Dir["/srv/mail/members/#{year}*/*"]

  # select messages that have a subject line starting with [MEMBER NOMINATION]
  emails = []
  archive.each do |email|
    next if email.end_with? '/index'
    message = IO.read(email, mode: 'rb')
    next unless message[/^Date: .*/].to_s.include? year
    subject = message[/^Subject: .*/]
    next if not subject # HACK: allow script to continue if bogus email
    next unless subject.upcase.include? "MEMBER"
    next unless subject.upcase =~ /NOMI[NM]ATION/
    mail = Mail.new(message.encode(message.encoding, crlf_newline: true))
    next if mail.subject.downcase == 'member nomination process'
    emails << mail if mail.subject =~ /^\[?MEMBER(SHIP)? NOMI[MN]ATION\]?/i
  end

  # parse nominations for names and ids
  # TODO: share code with nominees.rb if possible
  nominations = IO.read(File.join(cur_mtg_dir, 'nominated-members.txt')).
    encode("utf-8", "utf-8", :invalid => :replace).
    scan(/^---+--\s+(?:[a-z_0-9-]+)\s+(.*?):?\n/).flatten

  nominations.shift if nominations.first == '<empty line>'
  nominations.pop if nominations.last.empty?

  nominations.map! do |line|
    {name: line.gsub(/<.*|\(\w+@.*/, '').strip, id: line[/([.\w]+)@/, 1]}
  end

  # preload names
  people = ASF::Person.preload('cn',
    nominations.map {|nominee| ASF::Person.find(nominee[:id])})

  return nominations, people, emails
end

# produce HTML output of reports, highlighting ones that have not (yet)
# been posted
_html do
  _style %{
    .missing {background-color: yellow}
    .flexbox {display: flex; flex-flow: row wrap}
    .flexitem {flex-grow: 1}
    .flexitem:first-child {order: 2}
    .flexitem:last-child {order: 1}
    .count {margin-left: 4em}
  }
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        '/members/memberless-pmcs' => 'PMCs with no/few ASF Members',
        '/members/watch' => 'Watch list for potential Member candidates',
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _ 'This script checks new member nomination statements from members@ against the official meeting ballot files, and highlights differences. '
        _ 'This probably only works in the period shortly before or after a Members meeting!'
      }
    ) do
      cur_mtg_dir = MeetingUtil.get_latest(MEETINGS)
      nominations, people, emails = setup_data(cur_mtg_dir)
      _div.flexbox do
        _div.flexitem do
          _h1_! do
            _a 'Nominees', href: 'watch/nominees'
            _ ' in '
            _a 'svn', href: File.join(cur_mtg_dir, 'nominated-members.txt')
          end

          _p.count "Count: #{nominations.count}"

          _ul nominations.sort_by {|nominee| nominee[:name]} do |nominee|
            _li! do
              person = ASF::Person.find(nominee[:id])
              match = /\b(#{nominee[:name]}|#{person.public_name})\b/i

              if emails.any? {|mail| mail.subject.downcase =~ match}
                _a.present person.public_name, href: "#{ROSTER}/#{nominee[:id]}"
              else
                _a.missing person.public_name, href: "#{ROSTER}/#{nominee[:id]}"
              end

              if nominee[:name] != person.public_name
                _span " (as #{nominee[:name]})"
              end
            end
          end
        end

        nominees = nominations.map! {|person| person[:name]}
        nominees += people.map {|person| person.public_name}

        _div.flexitem do
          _h1_.posted! do
            _a "Posted", href:
              'https://mail-search.apache.org/members/private-arch/members/'
            _ " nominations reports"
          end

          _p.count "Count: #{emails.count}"

          # attempt to sort reports by nominee name
          emails.sort_by! do |mail|
            mail.subject.downcase.gsub('- ', '').sub(/\[.*?\]\s*/, '')
          end

          # output an unordered list of subjects linked to the message archive
          _ul emails do |mail|
            _li do
              # ERB::Util.url_encode changes space to %20 as required in the path component
              href = MBOX + mail.date.strftime('%Y%m') + '.mbox/' +
              ERB::Util.url_encode('<' + mail.message_id + '>')

              if nominees.any? {|name| mail.subject =~ /\b#{name}\b/i}
                _a.present mail.subject, href: href
              else
                _a.missing mail.subject, href: href
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
  _ reports do |mail| # TODO: reports is not defined
    _subject mail.subject
    _link MBOX + ERB::Util.url_encode('<' + mail.message_id + '>') # TODO looks wrong: does not agree with href above
    _missing missing.any? {|title| mail.subject.downcase =~ /\b#{title}\b/}
  end
end
