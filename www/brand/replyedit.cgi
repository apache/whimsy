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

PAGETITLE = "DEMO: proposed UI for editing a response to question from boilerplate"
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
          _ ' of a proposed editing ui for Boilerplate Reply to a previously selected question. See '
          _a 'Proposed how to reply guide', href: 'https://svn.apache.org/repos/private/foundation/Brand/replies-readme.md'
        end
        _p do
          _ 'This would allow the user to edit the selected boilerplate reply, including options of how/when to send, and a button to actually submit a reply for sending. '
        end
      }
    ) do
      _h3 'DEMO: wireframe of Edit & Send Reply display', id: 'listheader'

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
            _td "(This would be some sort of snipped display of the message the user is replying to)"
            _td ''
          end
        end
      end
      
      _h3 'Edit Your Reply'
      _hr
      _p 'Dear user, thank you for respecting Apache Brands.  Blah blah, foo bar, blah (this is boilerplate content) '
      _p '(Either have the whole content be in an edit box, or just a selected part)'
      _p '<EDIT BOX FOR THE USER TO CHANGE THE TEXT OF THE REPLY>'
      _p 'Please see the FAQ that most likely applies to your question (this is boilerplate content) https://example.com/trademarks/faq1'
      _p '-- '
      _p '  $users-name from whimsy login'
      _p '  On behalf of the Official Brand Managment Committee'
      _hr
      _p do
        _a 'Send reply', href: '#', onclick: "alert('This would submit the reply to be sent the usual way (Reply-All, Reply-To: the list, etc.).');"
        _ ' | '
        _a 'Submit draft', href: '#', onclick: "alert('This would submit the reply as a DRAFT for someone else to confirm and send.');"
        _ ' | '
        _a 'Cancel', href: '#', onclick: "alert('This would cancel the action, going back to the mail list.');"
      end
    end
  end
end
