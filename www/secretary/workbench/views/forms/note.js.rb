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
# Add/edit message notes
#

class Note < Vue
  def render
    _div.partmail! do
      _h3 'Note'
      _textarea value: @notes, name: 'notes'

      _input.btn.btn_primary value: 'Save', type: 'submit', 
        onClick: submit
    end
  end

  def created()
    @@headers.secmail ||= {}
    @@headers.secmail.notes ||= ''
    @notes = @@headers.secmail.notes
  end

  def submit()
    data = {
      message: window.parent.location.pathname,
      notes: @notes
    }

    HTTP.post('../../actions/note', data).then {|result|
      window.location.reload()
    }.catch {|message|
      alert message
    }
  end
end
