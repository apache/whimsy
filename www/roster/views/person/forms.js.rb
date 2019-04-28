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
# Show a list of a person's forms on file
#

class PersonForms < Vue
  def render
    committer = @@person.state.committer
    documents = "https://svn.apache.org/repos/private/documents"

    _div.row do
      _div.name 'Forms on file'

      _div.value do
        _ul do
          for form in committer.forms
            link = committer.forms[form]
            
            if form == 'icla'
              _li do
                if link == '' # has ICLA bu no karma to view it
                  _ 'ICLA'
                else
                  _a 'ICLA', href: "#{documents}/iclas/#{link}"
                end
              end
            elsif form == 'member'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Membership App'
                else
                  _a 'Membership App',
                    href: "#{documents}/member_apps/#{link}"
                end
              end
            else
              _li "#{form}: #{link}"
            end
          end
        end
      end
    end
  end
end
