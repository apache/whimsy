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

require 'active_support/time'
require 'active_support/core_ext/integer/inflections.rb'

# read template for the reminders
@reminder.untaint if @reminder =~ /^reminder\d$/
@reminder.untaint if @reminder =~ /^non-responsive$/
template = File.read("templates/#@reminder.txt")

# find the latest agenda
agenda = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort.last.untaint

# determine meeting time
us_pacific = TZInfo::Timezone.get('US/Pacific')
meeting = Time.new(*agenda[/\d[\d_]+/].split('_').map(&:to_i), 10, 30)
meeting = us_pacific.local_to_utc(meeting).in_time_zone(us_pacific)
dueDate = meeting - 7.days

# substitutable variables
vars = {
  meetingDate:  meeting.strftime("%a, %d %b %Y at %H:%M %Z"),
  month: meeting.strftime("%B"),
  year: meeting.year.to_s,
  timeZoneInfo: File.read(agenda)[/Other Time Zones: (.*)/, 1],
  dueDate:  dueDate.strftime("%a %b #{dueDate.day.ordinalize}"),
  agenda: meeting.strftime("https://whimsy.apache.org/board/agenda/%Y-%m-%d/")
}

# perform the substitution
vars.each {|var, value| template.gsub! "[#{var}]", value}

# extract subject
subject = template[/Subject: (.*)/, 1]
template[/Subject: .*\s+/] = ''

# return results
{subject: subject, body: template}
