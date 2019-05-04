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
# Scan board@ for feedback threads.  Return number of responses in each.
#

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
    responses[date] ||= Hash.new {|hash, key| hash[key] = 0}
    responses[date][pmc] += 1
  end
end

responses.each {|key, value| responses[key] = responses[key].sort.to_h}
responses.sort.to_h
