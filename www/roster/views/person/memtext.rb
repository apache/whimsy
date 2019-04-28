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
# Render and edit a person's members.txt entry
#

class PersonMemberText < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'memtext' do
      _div.name 'Members.txt'

      _div.value do
        if @@edit == :memtext

          _form.inline method: 'post' do
            _div do
              _textarea committer.member.info, name: 'entry'
            end
            _button.btn.btn_primary 'submit'
          end

        else

          _pre committer.member.info,
            class: ('small' if committer.member.info =~ /.{81}/)
        end
      end
    end
  end
end
