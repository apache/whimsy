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
# A button that will toggle offline status
#
class Offline < Vue
  def initialize
    @disabled = false
  end

  def render
    if Server.offline
      _button.btn.btn_primary 'go online', onClick: click, disabled: @disabled
    else
      _button.btn.btn_primary 'go offline', onClick: click, disabled: @disabled
    end
  end

  def click(event)
    if Server.offline
      @disabled = true

      Pending.dbget do |pending|
        # construct arguments to fetch
        args = {
          method: 'post',
          credentials: 'include',
          headers: {'Content-Type' => 'application/json'},
          body: {agenda: Agenda.file, pending: pending}.inspect
        }

        fetch('../json/batch', args).then {|response|
          if response.ok
            Pending.dbput({})
            response.json().then do |pending| 
              Server.pending = pending
            end
            Pending.setOffline(false)
          else
            response.text().then do |text| 
              alert("Server error: #{response.status}")
              console.log text
            end
          end

          @disabled = false
        }.catch {|error|
          alert(error)
          @disabled = false
        }
      end
    else
      Pending.setOffline(true)
    end
  end
end
