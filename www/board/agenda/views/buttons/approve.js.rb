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
# Approve/Unapprove a report
#
class Approve < Vue
  def initialize
    @disabled = false
  end

  # render a single button
  def render
    _button.btn.btn_primary request, onClick: self.click, disabled: @disabled
  end

  # set request (and button text) depending on whether or not the
  # not this items was previously approved
  def request
    if Pending.approved.include? @@item.attach
      'unapprove'
    elsif Pending.unapproved.include? @@item.attach
      'approve'
    elsif @@item.approved and @@item.approved.include? User.initials
      'unapprove'
    else
      'approve'
    end
  end

  # when button is clicked, send request
  def click(event)
    data = {
      agenda: Agenda.file,
      initials: User.initials,
      attach: @@item.attach,
      request: request
    }

    @disabled = true
    Pending.update 'approve', data do |pending|
      @disabled = false
    end
  end
end
