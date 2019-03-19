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
person = ASF::Person.find(ARGV.first || ENV['USER'] || Etc.getlogin)

ASF::Mail.configure

mail = Mail.new do
  from "#{person.public_name} <#{person.id}@apache.org>"
  to "#{person.public_name} <#{person.mail.first}>"
  subject 'test mail'
  body "sent from #{`hostname`}"
end

puts mail.to_s
puts
mail.deliver!
