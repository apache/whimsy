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
# Render and edit a person's GitHub user name
#

class PersonGitHub < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'github' do
      _div.name 'GitHub username'

      _div.value do

        if @@edit == :github

          _form method: 'post' do
            current = 1
            prefix = 'githubuser'
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.githubUsername do |name|
              _input style: 'font-family:Monospace', size: 20, name: prefix + current, value: name
              _br              
              current += 1
            end
            # Spare field to allow new entry to be added
            _input style: 'font-family:Monospace', size: 20, name: prefix + current, placeholder: '<new GitHub name>'
            _br             
            
            _input type: 'submit', value: 'submit'
          end

        else
          if committer.githubUsername.empty?
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.githubUsername do |gh|
              _li do
                _a gh, href: "https://github.com/" + gh +"/" # / catches trailing spaces
                unless gh =~ /^[-0-9a-zA-Z]+$/ # should agree with the validation in github.json.rb
                  _ ' '
                  _span.bg_warning "Invalid: '#{gh}' expecting only alphanumeric and '-'"
                end
              end
            end
          end
        end
      end
    end
  end
end

