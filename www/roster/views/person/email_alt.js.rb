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
# Render and edit a person's alt E-mail addresses
#

class PersonEmailAlt < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'email_alt' do
      _div.name 'Email addresses (alt)'

      _div.value do

        if @@edit == :email_alt

          _form method: 'post' do
            current = 1
            prefix = 'email_alt' # must agree with email_alt.json.rb
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.email_alt do |key|
              _input name: prefix + current, value: key, size: 30
              _br              
              current += 1
            end
            # Spare field to allow new entry to be added
            _input name: prefix + current, placeholder: '<alternate email>', size: 30
            _br             

            _input type: 'submit', value: 'submit'
          end

        else

          if committer.email_alt.length == 0
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.email_alt do |mail|
              _li do
                _a mail, href: 'mailto:' + mail
              end
            end
          end
        end
      end
    end
  end
end
