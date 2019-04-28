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

PAGETITLE = "Member's Meeting Attendance Cross-Check" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'json'

# read in attendance
meetings = ASF::SVN['Meetings']
json = JSON.parse(IO.read File.join(meetings, 'attendance.json'))
attend = json['matrix'].keys

# parse received info
added = Hash.new('unknown')
Dir[File.join(meetings, '*', 'memapp-received.txt')].each do |received|
  meeting = File.basename(File.dirname(received))
  next if meeting.include? 'template'
  text = File.read(received)
  list = text.scan(/<(.*)@.*>.*Yes/i) + 
    text.scan(/^(?:no\s*)*(?:yes\s+)+(\w\S*)/)
  list.flatten.each {|id| added[id] = meeting}
end

# cross check against members.txt
missing = []
ASF::Member.list.each do |id, info|
  unless attend.delete(info[:name]) or info['status']
    missing << [info[:name], added[id]]
  end
end

# produce HTML
_html do
  _whimsy_body(
    title: PAGETITLE,
    related: {
      '/members/non-participants' => 'Members Not Attending X Meetings',
      '/members/inactive' => 'Inactive Member Feedback Form',
      '/members/proxy' => 'Members Meeting Proxy Assignment',
      '/members/subscriptions' => 'Members@ Mailing List Crosscheck'
    },
    helpblock: -> {
      _ 'This script cross-checks all people listed in members.txt versus the official attendance.json file that notes which members attended (or proxied) which meetings.'
      _ "Includes data through #{json['dates'].last} meeting."
    }
  ) do
    _h2_ 'Listed as attending a members meeting, but not in members.txt; note name changes or spelling differences may be the culprit.'
    _ul do
      attend.sort.each do |name|
        _li name
      end
    end
    
    _h2_ 'Listed in members.txt but not listed as attending a members meeting.'
    _table do
      _thead do
        _th 'Name'
        _th 'Date added as a member'
      end
      missing.sort.each do |name, meeting|
        next if meeting =~ /^2015/
        _tr_ do
          _td name
          _td meeting
        end
      end
    end
  end
end
