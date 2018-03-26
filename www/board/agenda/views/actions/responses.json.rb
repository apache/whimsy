require 'date'

maildir = '/srv/mail/board/'
start = maildir + (Date.today - 365).strftime("%Y%m")

responses = {}

Dir[maildir + '*'].sort.each do |dir|
  next unless dir >= start
  Dir[dir.untaint + '/*'].each do |msg|
    text = File.open(msg.untaint, 'rb') {|file| file.read}
    subject = text[/^Subject: .*/]
    next unless subject and subject =~ /Board feedback on .* report/
    date, pmc = subject.scan(/Board feedback on ([-\d]+) (.*) report/).first
    next unless date
    responses[date] ||= []
    unless responses[date].include? pmc
      responses[date].push pmc
    end
  end
end

responses.values.each {|value| value.sort!}
responses.sort.to_h
