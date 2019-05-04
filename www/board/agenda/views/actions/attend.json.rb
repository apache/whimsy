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
# Indicate intention to attend / regrets for meeting
#

if @action == 'regrets'
  message = "Regrets for the meeting."
else
  message = "I plan to attend the meeting."
end

Agenda.update(@agenda, message) do |agenda|

  rollcall = agenda[/^ \d\. Roll Call.*?\n \d\./m]
  rollcall.gsub!(/ +\n/, '')

  directors = rollcall[/^ +Directors.*?:\n\n.*?\n\n +Directors.*?:\n\n.*?\n\n/m]
  officers = rollcall[/^ +Executive.*?:\n\n.*?\n\n +Executive.*?:\n\n.*?\n\n/m]
  guests = rollcall[/^ +Guests.*?:\n\n.*?\n\n/m]

  if directors.include? @name

    updated = directors.sub /^ .*#{@name}.*?\n/, ''

    if @action == 'regrets'
      updated[/Absent:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /:\n\n +none\n/, ":\n\n"
      updated.sub! /Present:\n\n\n/, "Present:\n\n        none\n\n"
    else
      updated[/Present:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /Absent:\n\n\n/, "Absent:\n\n        none\n\n"

      # sort Directors
      updated.sub!(/Present:\n\n(.*?)\n\n/m) do |match|
        before=$1
        after=before.split("\n").sort_by {|name| name.split.rotate(-1)}
        match.sub(before, after.join("\n"))
      end
    end

    rollcall.sub! directors, updated

  elsif officers.include? @name

    updated = officers.sub /^ .*#{@name}.*?\n/, ''

    if @action == 'regrets'
      updated[/Absent:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /:\n\n +none\n/, ":\n\n"
      updated.sub! /Present:\n\n\n/, "Present:\n\n        none\n\n"
    else
      updated[/Present:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /Absent:\n\n\n/, "Absent:\n\n        none\n\n"
    end

    rollcall.sub! officers, updated

  elsif @action == 'regrets'

    updated = guests.sub /^ .*#{@name}.*?\n/, ''
    updated.sub! /:\n\n\n/, ":\n\n        none\n"

    rollcall.sub! guests, updated

  elsif not guests.include? @name

    updated = guests.sub /\n\Z/, "\n        #{@name}\n"
    updated.sub! /:\n\n +none\n/, ":\n\n"

    rollcall.sub! guests, updated

  end

  agenda[/^ \d\. Roll Call.*?\n \d\./m] = rollcall

  agenda
end
