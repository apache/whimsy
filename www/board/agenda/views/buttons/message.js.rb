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
# Message area for backchannel
#
class Message < Vue
  def initialize
    @disabled = false
    @message = ''
  end

  # render an input area in the button area (a very w-i-d-e button)
  def render
    _form onSubmit: self.sendMessage do
      _input.chatMessage! value: @message
    end
  end

  # autofocus on the chat message when the page is initially displayed
  def mounted()
    document.getElementById("chatMessage").focus()
  end

  # send message to server
  def sendMessage(event)
    event.stopPropagation()
    event.preventDefault()

    if @message
      post 'message', agenda: Agenda.file, text: @message do |message|
        Chat.add message
        @message = ''
      end
    end

    return false
  end
end
