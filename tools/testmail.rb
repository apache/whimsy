#
# Test the ability to send email to non-apache.org email addresses
#

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'whimsy/asf'
require 'mail'
require 'etc'
person = ASF::Person.find(Etc.getlogin)

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
