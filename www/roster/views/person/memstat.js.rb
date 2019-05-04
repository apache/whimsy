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
# Render and edit a person's member status
#

class PersonMemberStatus < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: ('memstat' if @@person.props.auth.secretary) do
      _div.name 'Member status'

      if committer.member.status
        _div.value do
          _span committer.member.status

         if @@edit == :memstat
           _form.inline method: 'post' do
             if committer.member.status.include? 'Active'
               _button.btn.btn_primary 'move to emeritus',
                 name: 'action', value: 'emeritus'
             elsif committer.member.status.include? 'Emeritus'
               _button.btn.btn_primary 'move to active',
                 name: 'action', value: 'active'
             end
           end
         end
        end
      end
    end
  end
end
