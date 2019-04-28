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

PAGETITLE = "Incubator Podling Mailing Lists" # Wvisible:incubator mail

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        'https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png' => 'Apache Incubator Egg Logo',
        'https://incubator.apache.org/projects/' => 'Incubator Podling List',
        '/incubator/moderators' => 'Incubator Mailing List Moderators'
      },
      helpblock: -> {
        _ 'This provides a complete listing of Incubator podling mailing lists, derived from '
        _a 'https://whimsy.apache.org/test/dataflow.cgi#/lib/whimsy/asf/podlings.rb', href: '/test/dataflow.cgi#/lib/whimsy/asf/podlings.rb'
      }
    ) do
      lists = ASF::Mail.lists

      _table.table do
        _tr do
          _th 'podling'
          _th 'status'
          _th 'reports'
          _th 'mailing lists'
        end

        ASF::Podling.list.sort_by {|podling| podling.name}.each do |podling|
          next if podling.status == 'retired'
          next if podling.status == 'graduated'

          _tr_ do
            _td! do
              _a podling.display_name, 
                href: "http://incubator.apache.org/projects/#{podling.name}.html"
            end

            _td podling.status
            _td podling.reporting.join(', ')
            _td lists.select {|list| podling.mail_list?(list) }.join(', ')
          end
        end
      end
    end
  end
end
