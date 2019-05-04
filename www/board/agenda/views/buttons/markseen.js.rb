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
# A button that mark all comments as 'seen', with an undo option
#
class MarkSeen < Vue
  def initialize
    @disabled = false
    @label = 'mark seen'
    MarkSeen.undo = nil
  end

  def render
    _button.btn.btn_primary @label, onClick: self.click, disabled: @disabled
  end

  def click(event)
    @disabled = true

    if MarkSeen.undo
      seen = MarkSeen.undo
    else
      seen = {}
      Agenda.index.each do |item|
        if item.comments and not item.comments.empty?
          seen[item.attach] = item.comments 
        end
      end
    end

    post 'markseen', seen: seen, agenda: Agenda.file do |pending|
      @disabled = false

      if MarkSeen.undo
        MarkSeen.undo = nil
        @label = 'mark seen'
      else
        MarkSeen.undo = Pending.seen
        @label = 'undo mark'
      end

      Pending.load pending
    end
  end
end
