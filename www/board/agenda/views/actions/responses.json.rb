#
# Scan board@ for feedback threads.  Return number of responses in each.
#

require 'date'

maildir = '/srv/mail/board/'
start = maildir + (Date.today - 365).strftime("%Y%m")

responses = {}

Dir[maildir + '*'].sort.each do |dir|
  next unless dir >= start
  Dir[dir + '/*'].each do |msg|
    text = File.open(msg, 'rb') {|file| file.read}
    subject = text[/^Subject: .*/]
    next unless subject and subject =~ /Board feedback on .* report/
    date, pmc = subject.scan(/Board feedback on ([-\d]+) (.*) report/).first
    next unless date
    responses[date] ||= Hash.new {|hash, key| hash[key] = 0}
    responses[date][pmc] += 1
  end
end

responses.each {|key, value| responses[key] = responses[key].sort.to_h}
responses.sort.to_h
