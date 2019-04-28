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
# Organization Chart
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      title: 'ASF Organization Chart',
      breadcrumbs: {
        roster: '.',
        orgchart: 'orgchart/'
      }
    ) do
      _whimsy_panel_table(
        title: 'Corporate Officer Listing (Member-private version)',
        helpblock: -> {
          _ 'This table lists all Corporate officers of the ASF, not including Apache TLP project Vice Presidents (except for a few special PMCs). '
          _a '(View source data)', href: 'https://svn.apache.org/repos/private/foundation/officers/personnel-duties/'
          _ ' A publicly viewable version (not including private data) of this is also '
          _a 'posted here.', href: 'https://whimsy.apache.org/foundation/orgchart/'
        }
      ) do
        _table.table do
          _thead do
            _th 'Title'
            _th 'Contact, Chair, or Person holding that title'
            _th 'Public Website'
          end

          _tbody do
            @org.sort_by {|key, value| value['info']['role']}.each do |key, value|
              _tr_ do
                # title
                _td do
                  _a value['info']['role'], href: "orgchart/#{key}"
                end

                # person holding the role
                _td do
                  id = value['info']['id'] || value['info']['chair']
                  _a ASF::Person.find(id).public_name, href: "committer/#{id}"
                end
                
                # Website - often valuable to people looking for info
                _td do
                  value['info']['website'].nil? ? _('')  : _a('website', href: value['info']['website'])
                end
              end
            end
          end
        end
      end
    end
  end
end
