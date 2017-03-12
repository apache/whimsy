#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'mail'
require 'wunderbar'
require 'whimsy/asf'

# link to members private-arch
MBOX = 'https://mail-search.apache.org/members/private-arch/members/'

# link to roster page
ROSTER = 'https://whimsy.apache.org/roster/committer'

# get a list of current members messages
year = Time.new.year.to_s
archive = Dir["/srv/mail/members/#{year}*/*"]

# select messages that have a subject line starting with [MEMBER NOMINATION]
emails = []
archive.each do |email|
  next if email.end_with? '/index'
  message = IO.read(email, mode: 'rb')
  next unless message[/^Date: .*/].to_s.include? year
  subject = message[/^Subject: .*/]
  next unless subject.upcase.include? "MEMBER"
  next unless subject.upcase =~ /NOMI[NM]ATION/
  mail = Mail.new(message)
  next if mail.subject.downcase == 'member nomination process'
  emails << mail if mail.subject =~ /^\[?MEMBER(SHIP)? NOMI[MN]ATION\]?/i
end

# parse nominations for names and ids
MEETINGS = ASF::SVN['private/foundation/Meetings']
meeting = Dir["#{MEETINGS}/2*"].sort.last
nominations = IO.read("#{meeting}/nominated-members.txt").
  scan(/^---+--\s+(.*?)\n/).flatten

nominations.shift if nominations.first == '<empty line>'
nominations.pop if nominations.last.empty?

nominations.map! do |line| 
  {name: line.gsub(/<.*|\(\w+@.*/, '').strip, id: line[/([.\w]+)@/, 1]}
end

# preload names
people = ASF::Person.preload('cn', 
  nominations.map {|nominee| ASF::Person.find(nominee[:id])})

# location of svn repository
svnurl = `cd #{meeting}; svn info`[/URL: (.*)/, 1]

# produce HTML output of reports, highlighting ones that have not (yet)
# been posted
_html do
  _title 'Member nominations cross-check'

  _style %{
    .missing {background-color: yellow}
    .flexbox {display: flex; flex-flow: row wrap}
    .flexitem {flex-grow: 1}
    .flexitem:first-child {order: 2}
    .flexitem:last-child {order: 1}
    .count {margin-left: 4em}
  }

  # common banner
  _a href: 'https://whimsy.apache.org/' do
    _img title: "ASF Logo", alt: "ASF Logo",
      src: "https://www.apache.org/img/asf_logo.png"
  end

  _div.flexbox do
    _div.flexitem do
      _h1_! do
        _a 'Nominees', href: 'watch/nominees'
        _ ' in '
        _a 'svn', href: File.join(svnurl, 'nominated-members.txt')
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
          href = MBOX + mail.date.strftime('%Y%m') + '.mbox/' + 
            URI.escape('<' + mail.message_id + '>')

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

# produce JSON output of reports
_json do
  _ reports do |mail|
    _subject mail.subject
    _link MBOX + URI.escape('<' + mail.message_id + '>')
    _missing missing.any? {|title| mail.subject.downcase =~ /\b#{title}\b/}
  end
end
