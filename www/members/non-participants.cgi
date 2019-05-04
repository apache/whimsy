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

PAGETITLE = "Active Members not participating in meetings" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'date'
require 'json'
require 'wunderbar/jquery/stupidtable'

# separator / is added when link is generated
ROSTER = "/roster/committer"

# locate and read the attendance file
MEETINGS = ASF::SVN['Meetings']
attendance = JSON.parse(IO.read(File.join(MEETINGS, 'attendance.json')))

# extract and format dates
dates = attendance['dates'].sort.
map {|date| Date.parse(date).strftime('%Y-%b')}

# compute mappings of names to ids
members = ASF::Member.list
active = Hash[members.select {|id, data| not data['status']}]
nameMap = Hash[members.map {|id, data| [id, data[:name]]}]
idMap = Hash[nameMap.to_a.map(&:reverse)]

# analyze attendance
matrix = attendance['matrix'].map do |name, meetings|
  id = idMap[name]
  next unless id and active[id]
  data = meetings.sort.reverse.map(&:last)
  first = data.length
  missed = (data.index {|datum| datum != '-'} || data.length)
  
  [id, name, first, missed]
end

# produce HTML
_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Select A Date:',
      related: {
        '/members/attendance-xcheck' => 'Members Meeting Attendance Crosscheck',
        '/members/inactive' => 'Inactive Member Feedback Form',
        '/members/proxy' => 'Members Meeting Proxy Assignment',
        '/members/subscriptions' => 'Members@ Mailing List Crosscheck'
      },
      helpblock: -> {
        _form_ do
          _span "List of members that have not participated, starting with the "
          _select name: 'meetingsMissed', onChange: 'this.form.submit()' do
            dates.reverse.each_with_index do |name, i|
              _option name, value: i+1, selected: (i+1 == @meetingsMissed.to_i)
            end
          end
          _span "meeting.  Active members does not include emeritus or deceased members. Includes data thru #{attendance['dates'].last} meeting."
        end
        _h4 'Definitions'
        _p do
          _ 'Participating is defined by doing at least one of the following:'
          _ul do
            _li 'Attending a members meeting in IRC'
            _li 'Voting in an election'
            _li 'Assigning a proxy'
          end
        end
      }
    ) do
    @meetingsMissed = (@meetingsMissed || 3).to_i
    count = 0
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'Name', data_sort: 'string'
          _th 'Membership start date', data_sort: 'string'
          _th 'Last participated', data_sort: 'string'
        end
      end
      
      matrix.each do |id, name, first, missed|
        next unless id
        
        if missed >= @meetingsMissed
          _tr_ do
            _td! {_a nameMap[id], href: "#{ROSTER}/#{id}"}
            _td dates[-first-1] || dates.first
            if missed >= first
              _td {_em 'never'}
            else
              _td dates[-missed-1]
            end
          end
          count += 1
        end
      end
    end
    
    _div.count "Count: #{count} members inactive for #{@meetingsMissed} meetings."
    
    _script %{
      var table = $(".table").stupidtable();
      table.on("aftertablesort", function (event, data) {
        var th = $(this).find("th");
        th.find(".arrow").remove();
        var dir = $.fn.stupidtable.dir;
        var arrow = data.direction === dir.ASC ? "&uarr;" : "&darr;";
        th.eq(data.column).append('<span class="arrow">' + arrow +'</span>');
        });
      }
    end
  end
end
  
_json do
  meetingsMissed = (@meetingsMissed || 3).to_i
  
  inactive = matrix.select do |id, name, first, missed|
    id and missed >= meetingsMissed
  end
  
  Hash[inactive.map {|id, name, first, missed| 
    [id, {name: name, missed: missed, status: 'no response yet'}]
    }]
end
