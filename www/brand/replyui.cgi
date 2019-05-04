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

PAGETITLE = "DEMO: proposed UI for popup/dialog to choose a reply boilerplate"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
        "https://svn.apache.org/repos/private/foundation/Brand/runbook.txt" => "Members-only Trademark runbook",
        "https://lists.apache.org/list.html?trademarks@apache.org" => "Ponymail interface to trademarks@"
      },
      helpblock: -> {
        _p do 
          _ 'This is a wireframe '
          _strong 'DEMO'
          _ ' of a proposed dialog/popup way to Choose a specific Boilerplate Reply to a previously selected question. See '
          _a 'Proposed how to reply guide', href: 'https://svn.apache.org/repos/private/foundation/Brand/replies-readme.md'
        end
        _p do
          _ 'This would be some listing of available Boilerplates with descriptions about each, so the user could choose one; that would then open it for editing as a Reply-All message to save. '
        end
      }
    ) do
      _h3 'DEMO: wireframe of Choose Reply display', id: 'listheader'

      _table.table.table_hover.table_striped do
        _thead_ do
          _tr do
            _th 'Who'
            _th 'Subject'
            _th 'Flags'
          end
        end
        _tbody do
          _tr_ do
            _td 'Jane Doe'
            _td 'Help! I want to abuse Apache Foo brand!'
            _td '(flag1)'
          end
          _tr_ do
            _td ' '
            _td "(This would be some sort of snipped display of the message the user is selecting a reply to)"
            _td ''
          end
        end
      end
      
      _h3 'Choose A Reply to edit and send for this question'
      _p 'This could be a choicelist or similar to select from avaialble Replies'
      
      _ul do
        _li do 
          _ 'BOOK | Point to FAQ about published books, magazines, etc.'
          _a 'Select this reply', href: '#', onclick: "alert('This would select this reply to edit in the browser.');"
        end
        _li do
          _li 'DOMAIN | Point to FAQ about use in domain.names'
          _a 'Select this reply', href: '/brand/replyedit.cgi'
        end
        _li do
          _li 'EVENT | Point to FAQ about use in conferences or events'
          _a 'Select this reply', href: '/brand/replyedit.cgi'
        end
        _li do
          _li 'PRODUCT | Point to FAQ about use in software products of any kind'
          _a 'Select this reply', href: '/brand/replyedit.cgi'
        end
        _li '(... etc. as many choices as are written)'
      end
    end
  end
end
