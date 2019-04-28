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
# Render and edit a person's SSH keys
#

class PersonSshKeys < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'sshkeys' do
      _div.name 'SSH keys'

      _div.value do

        if @@edit == :sshkeys

          _form method: 'post' do
            current = 1
            prefix = 'sshkeys' # must agree with sshkeys.json.rb
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.ssh do |key|
              _input style: 'font-family:Monospace', size: 100, name: prefix + current, value: key
              _br              
              current += 1
            end
            # Spare field to allow new entry to be added
            _input style: 'font-family:Monospace', size: 100, name: prefix + current, placeholder: '<enter a new ssh key>'
            _br             

            _input type: 'submit', value: 'submit'
          end

        else
          if committer.ssh.empty?
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.ssh do |key|
              _li.ssh do
                _pre.wide key
              end
            end
          end
        end
      end
    end
  end
end

