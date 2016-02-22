#!/usr/bin/ruby1.9.1
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'mail'
require 'wunderbar'
require 'whimsy/asf'

# link to members private-arch
MBOX = 'https://mail-search.apache.org/members/private-arch/members/'

# get a list of current members messages
archive = Dir['/home/apmail/members/archive/*/*']

# select messages that have a subject line starting with [MEMBER NOMINATION]
emails = []
year = Time.new.year.to_s
archive.each do |email|
  next if email.end_with? '/index'
  message = IO.read(email, mode: 'rb')
  puts message[/^Date: .*/]
  next unless message[/^Date: .*/].to_s.include? year
  subject = message[/^Subject: .*/]
  next unless subject.include? "[MEMBER NOMINATION]"
  mail = Mail.new(message)
  emails << mail if mail.subject.start_with? "[MEMBER NOMINATION]"
end

# 
MEETINGS = ASF::SVN['private/foundation/Meetings']
meeting = Dir["#{MEETINGS}/2*"].sort.last
nominations = IO.read("#{meeting}/nominated-members.txt").
  scan(/^-+--\s+(.*?)\n/).flatten.
  map {|name| name.gsub(/<.*|\(\w+@.*/, '').strip}
nominations.shift if nominations.first.empty?
nominations.pop if nominations.last.empty?


url = `cd #{meeting}; svn info`[/URL: (.*)/, 1]

# produce HTML output of reports, highlighting ones that have not (yet)
# been posted
_html do
  _style %{
    .missing {background-color: yellow}
  }

  _h1 "Nominations in SVN"
  _a File.basename(meeting), href: File.join(url, 'nominated-members.txt')
  _ul nominations.sort do |name|
    _li name
  end

  nominations.map!(&:downcase)

  _h1.posted! "Posted nominations reports"

  # attempt to sort reports by PMC name
  emails.sort_by! do |mail| 
    mail.subject.downcase.gsub('- ', '')
  end

  # output an unordered list of subjects linked to the message archive
  _ul emails do |mail|
    _li do
      href = MBOX + mail.date.strftime('%Y%m') + '.mbox/' + 
        URI.escape('<' + mail.message_id + '>')

      if nominations.any? {|name| mail.subject.downcase =~ /\b#{name}\b/}
        _a.present mail.subject, href: href
      else
        _a.missing mail.subject, href: href
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
