#!/usr/bin/env ruby
PAGETITLE = "Cross-check existing Board nominations" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'time'
require 'erb'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/member-files'
require 'whimsy/asf/meeting-util'
require_relative '../../tools/parsemail'
require 'whimsy/asf/time-utils'

# link to members private-arch
MBOX = 'https://mail-search.apache.org/members/private-arch/members/'

# link to roster page
ROSTER = '/roster/committer'
MEETINGS = ASF::SVN['Meetings']
MAIL_ROOT = '/srv/mail' # TODO: this should be config item in config.rb
# Only need these items
Email = Struct.new(:subject, :date, :message_id, :from, :asciiname)

# Encapsulate gathering data to improve error processing
def setup_data
  ParseMail.parse_main(['members']) # ensure we are up to date
  # get a list of current year's members@ emails
  # TODO: narrow down the search for member meetings later in the year.
  # Only the last couple of months are relevant
  year = Time.new.year.to_s
  indices = Dir[File.join(MAIL_ROOT, "members", "#{year}*.yaml")]

  # select messages that have a subject line starting with [BOARD NOMINATION]
  emails = []
  indices.each do |index|
    yaml = YamlFile.read(index)
    yaml.each do |key, value|
      subject = value[:Subject]
      next unless subject
      next if subject.include? 'What to expect'
      date = value[:Date]
      next unless date.include? year
      next unless /^\[?BOARD NOMI[MN]ATION\]? *(?<name>.*)/i =~ subject
      # N.B. the named capture only works if the RE is on the LHS
      messageid = value[:MessageId]
      emails << Email.new(subject, Time.parse(date).utc, messageid, [value[:From]], ASF::Person.asciize(name.delete('.'), nil))
    end
  end

  # parse nominations for names and ids
  nominations = ASF::MemberFiles.board_nominees.map do |id, hash|
    {id: id, name: hash['Public Name'], nominator: hash['Nominated by']}
  end

  # preload names
  ASF::Person.preload('cn',
    nominations.map {|nominee| ASF::Person.find(nominee[:id])})

  # build up the matches once
  nominations.each do |nominee|
    nominee[:match] = create_match(nominee)
  end
  return nominations, emails
end

# create the match RE from a nominee
def create_match(nominee)
  names = []
  pname = ASF::Person.asciize(nominee[:name], nil) # don't change non-words
  names << pname
  names << pname.delete('.')
  names << pname.sub(%r{ [A-Z] }, ' ') # drop initial
  names << pname.sub(/\bChristo(ph|f)er\b/, 'Chris') # Special
  personname = ASF::Person.find(nominee[:id]).public_name
  names << ASF::Person.asciize(personname, nil) if personname
  list = names.uniq.map {|name| Regexp.escape(name)}.join('|')
  # N.B. \b does not match if it follows ')', so won't match John (Fred)
  # TODO: Work-round is to also look for EOS, but this needs to be improved
  %r{\b(#{list})(\b|$)}i
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
    # Countdown until nominations for current meeting close
    latest_meeting_dir = ASF::MeetingUtil.latest_meeting_dir
    timelines = ASF::MeetingUtil.get_timeline(latest_meeting_dir)
    t_now = Time.now.to_i
    t_end = Time.parse(timelines['nominations_close_iso']).to_i
    nomclosed = t_now > t_end

    _whimsy_body(
      title: PAGETITLE,
      related: {
        'meeting.cgi' => 'Member Meeting FAQ and info',
        'nominate_board.cgi' => 'Nominate someone for the Board',
        'check_membernoms.cgi' => 'Cross-check existing New Member nominations',
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _b "For: #{timelines['meeting_type']} Meeting on: #{timelines['meeting_iso']}"
        _ 'This script checks board nomination statements from members@ against the official meeting ballot files, and highlights differences. '
        _ 'This only works in the period shortly before or after a Members meeting!'
        _br
        _ 'Entries are highlighted if they are not present in both lists.'
      }
    ) do
      if nomclosed
        _h1 "Nominations are CLOSED for Meeting: #{timelines['meeting_iso']}"
        _p 'Nominations must no longer be added to the nominations file'
      else
        _h3 "Nominations close in #{ASFTime.secs2text(t_end - t_now)} at #{Time.at(t_end).utc} for Meeting: #{timelines['meeting_iso']}"
        _p 'Please ensure all posted nominations are added to board_nominations.txt before then.'
      end
      cur_mtg_dir = File.basename(ASF::MeetingUtil.get_latest(MEETINGS))
      nominations, emails = setup_data
      _div.flexbox do
        _div.flexitem do
          _h1_! do
            _ 'Nominees in '
            _a 'svn', href: ASF::SVN.svnpath!('Meetings', cur_mtg_dir, 'board_nominations.txt')
          end

          _p.count "Count: #{nominations.count}"

          _ul(nominations.sort_by {|nominee| nominee[:name]}) do |nominee|
            _li! do
              person = ASF::Person.find(nominee[:id])

              if emails.any? {|mail| mail[:asciiname] =~ nominee[:match]}
                _a.present person.public_name || '??', href: "#{ROSTER}/#{nominee[:id]}"
              else
                _a.missing person.public_name || '??', href: "#{ROSTER}/#{nominee[:id]}"
                _ ' Nominated by: '
                _ nominee[:nominator]
              end

              if nominee[:name] != person.public_name
                _span " (as #{nominee[:name]})"
              end
            end
          end
        end

        _div.flexitem do
          _h1_.posted! do
            _a "Posted", href: MBOX
            _ " nominations"
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

              if nominations.any? {|nominee| mail[:asciiname] =~ nominee[:match]}
                _a.present mail.subject, href: href
              else
                _a.missing mail.subject, href: href
                _ ' From: '
                _ mail.from.first
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
    _missing(missing.any? {|title| mail.subject.downcase =~ /\b#{Regexp.escape(title)}\b/})
  end
end
