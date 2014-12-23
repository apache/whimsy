#!/usr/bin/ruby1.9.1
require 'whimsy/asf'
$SAFE = 1

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

request = ENV['REQUEST_URI'].sub(/^\/treasurer\/paypal\/?/, '')
request.untaint if request =~ /^\d{4}-\d\d$/
if request.tainted?
  print "Status: 401 Forbidden\r\n"
  print "Content-type: text/plain\r\n\r\n"
  print "Forbidden"
  exit
end

if File.exist?("/var/tools/treasurer/paypal/#{request}.html")
  print "Content-type: text/html; charset=utf-8\r\n\r\n"
  print File.read("/var/tools/treasurer/#{request}.html")
  exit
end

if File.exist?("/var/tools/treasurer/paypal/#{request}.txt")
  print "Content-type: text/plain; charset=utf-8\r\n\r\n"
  print File.read("/var/tools/treasurer/#{request}.txt")
  exit
end

print "Status: 404 Not-Found\r\n"
print "Content-type: text/plain\r\n\r\n"
print "Not here"
exit
