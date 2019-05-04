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
# Select and send item comments as feedback.
#

class Feedback < Vue
  def self.buttons()
    return [{button: SendFeedback}]
  end

  def initialize
    @list = nil
  end

  def render
    if @list == nil
      _h2 'Loading...'
    elsif @list.empty?
      _h2 'No feedback to send'
    else
      @list.each do |item|
        _h2 do
          _input type: 'checkbox', domPropsChecked: item.checked, 
            onClick:-> {item.checked = !item.checked}
          _ item.title
        end
        _pre.feedback item.mail
      end
    end
  end

  def mounted()
    EventBus.on :potential_feedback, self.potential_feedback

    fetch('feedback.json', credentials: 'include').then do |response|
      response.json().then do |json|
        # initially check each item which has not yet been sent
        json.each {|item| item.checked = !item.sent}

        EventBus.emit :potential_feedback, json
      end
    end
  end

  def beforeDestroy()
    EventBus.off :potential_feedback, self.potential_feedback
  end

  def potential_feedback(list)
    @list = list
  end
end

#
# Send feedback button
#

class SendFeedback < Vue
  def initialize
    @disabled = false
    @list = []
  end

  def render
    _button.btn.btn_primary 'send email', onClick: self.click, 
      disabled: @disabled || @list.empty? ||
        @list.all? {|item| !item.checked}
  end

  def mounted()
    EventBus.on :potential_feedback, self.potential_feedback
  end

  def beforeDestroy()
    EventBus.off :potential_feedback, self.potential_feedback
  end

  def potential_feedback(list)
    @list = list
  end

  def click(event)
    # gather a list of checked items
    checked = {}

    @list.each do |item|
      checked[item.title.gsub(/\s/, '_')] = true if item.checked
    end

    # construct arguments to fetch
    args = {
      method: 'post',
      credentials: 'include',
      headers: {'Content-Type' => 'application/json'},
      body: {checked: checked}.inspect
    }

    # send feedback
    @disabled = true
    fetch('feedback.json', args).then do |response|
      response.json().then do |json|
        # check each item which still has yet to be sent
        json.each {|item| item.checked = !item.sent}

        @list = json
        EventBus.emit :potential_feedback, @list
        @disabled = false

        # return to the Adjournment page
        Main.navigate 'Adjournment'
      end
    end
  end
end
