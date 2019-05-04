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

# Analyze proxies file and output data to remind proxies of IRC attendance lines
# TODO Add function to email proxies with their info
# TODO Add function to cross-check irc log that all proxy/attendee were marked

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'mail'

MEETINGS = ASF::SVN['Meetings']

# Get IRC attendance copy/paste lines for all proxies at a meeting
# @param meeting dir name of current meeting
# @return reminders {"proxy@apache.org" => ["IRC line", ...]}
# @see foundation/Meetings/*.rb for other scripts that deal with 
#   IRC log parsing, attendance marking, and proxy handling
def reminder_lines(meeting = File.basename(Dir[File.join(MEETINGS, '2*')].sort.last).untaint)
  lines = IO.read(File.join(MEETINGS, meeting, 'proxies'))
  proxylist = lines.scan(/\s\s(.{25})(.*?)\((.*?)\)/).map { |l| [l[0].strip, l[1].strip, l[2]]} # [["Shane Curcuru    ", "David Fisher ", "wave"], ...]
  copyproxy = Hash.new{|h,k| h[k] = [] }
  proxylist.each do |arr|
    copyproxy[arr[0]] << "#{arr[2].ljust(12)} | #{arr[1].strip} (proxy)"
  end
  copyproxy.delete('<name>')
  reminders = {}
  copyproxy.each do |nam, proxies|
    user = ASF::Person.list("(cn=#{nam})")
    if user.length == 1 # Copy to new array with their email instead of cn
      reminders[user[0].mail[0]] = ["#{user[0].id.ljust(12)} | #{user[0].cn}"]
      proxies.each do |l|
        reminders[user[0].mail[0]]  << "#{l}"
      end
    else
      # "Bogus: ASF::Person.list(#{nam}) not found, skipped!"
    end
  end
  return reminders
end

#### Main method - TODO needs to be integrated into meeting process
puts "START: reminder_lines()"
p = reminder_lines
puts p

