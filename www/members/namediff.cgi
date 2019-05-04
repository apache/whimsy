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

PAGETITLE = "Crosscheck Members Names With ICLAs"  # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        '/roster/members' => 'Listing Of All Members',
        'https://svn.apache.org/repos/private/foundation/officers/iclas.txt' => 'ICLA.txt Listing',
      },
      helpblock: -> {
        _p_ do
          _ 'Cross-check of members.txt vs iclas.txt.'
          _br
          _span.text_danger 'REMINDER: members.txt and Legal names below are NOT public data - keep this page confidential!'
        end
      }
    ) do
      ASF::ICLA.preload
      ldap_members = ASF::Member.list.map {|id, info| ASF::Person.find(id)}
      ASF::Person.preload('cn', ldap_members)
      
      _table.table.table_hover do
        _thead do
          _tr do
            _th 'availid', data_sort: 'string'
            _th data_sort: 'string' do
              _span.text_danger 'Name from members.txt'
            end
            _th 'Public name', data_sort: 'string'
            _th data_sort: 'string', data_sort_default: 'desc' do
              _span.text_danger 'Legal name (if different)'
            end
          end
        end
        
        ASF::Member.list.sort.each do |id, info|
          person = ASF::Person.find(id)
          
          if person.icla
            next if person.icla.name == info[:name]
            next if person.icla.legal_name == info[:name]
            _tr_ do
              _td id
              _td info[:name]
              _td person.icla.name
              if person.icla.name != person.icla.legal_name
                _td person.icla.legal_name
              else
                _td
              end
            end
          elsif ldap_members.include? person
            _tr_ do
              _td id
              _td info[:name]
              _td.bg_danger 'ICLA not on file', colspan: 2, data_sort_value: ''
            end
          end
        end
      end
      
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