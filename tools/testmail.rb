#!/usr/bin/env ruby
#
# Test the ability to send email to non-apache.org email addresses
#
# Should your local user id not match your ASF user id, either specify your
# ASF user as the first argument to this script, or set the USER environment
# variable.
#
# Note: this will send an email to THAT user.
#

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'mail'
require 'etc'
userid = ARGV.first || ENV['USER'] || Etc.getlogin

ASF::Mail.configure

mail = Mail.new do
  from "#{userid} <#{userid}@apache.org>"
  to "#{userid}@apache.org>"
  subject 'test mail'
  body "sent from #{`hostname`}"
end

puts mail.to_s
puts
mail.deliver!
