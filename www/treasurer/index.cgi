#!/usr/bin/env ruby
##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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
