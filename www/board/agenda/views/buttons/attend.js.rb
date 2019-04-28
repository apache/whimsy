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
class Attend < Vue
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary (attending ? 'regrets' : 'attend'),
      onClick: self.click, disabled: @disabled
  end

  # match person by either userid or name
  def attending
    return false unless @@item.people
    person = @@item.people[User.id]
    if person
      return person.attending
    else
      for id in @@item.people
        person = @@item.people[id]
        return person.attending if person.name == User.username
      end
      return false
    end
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      action: (attending ? 'regrets' : 'attend'),
      name: User.username,
      userid: User.id
    }

    @disabled = true
    post 'attend', data do |response|
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
