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
