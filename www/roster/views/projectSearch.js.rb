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
# Searchable Project roster
#

class ProjectSearch < Vue
  def render
    matches = []
    found = false

    search = @@search.downcase().strip().split(/\s+/)

    for id in @@project.roster do
      person = @@project.roster[id]

      match = search.all? {|term|
        id.include? term or person.name.downcase().include? term or
        person.role.downcase().include? term
      }

      next unless match or person.selected
      found = true if match

      person.id = id
      matches << person
    end

    matches = matches.sort_by {|person| person.name}

    _table.table.table_hover do
      _thead do
        _tr do
          _th if @@auth
          _th 'id'
          _th 'public name'
          _th 'role'
        end
      end

      _tbody do
        matches.each do |person|
          _tr key: "pmc_#{person.id}" do
            if @@auth
              _td do
                 _input type: 'checkbox', checked: person.selected || false,
                   onChange: -> {self.toggleSelect(person)}
              end
            end

            if person.member
              _td { _b { _a person.id, href: "committer/#{person.id}" } }
              _td { _b person.name }
            else
              _td { _a person.id, href: "committer/#{person.id}" }
              _td person.name
            end

            _td person.role
          end
        end
      end
    end

    _div.alert.alert_warning 'No matches' unless found
  end

  def toggleSelect(person)
    person.selected = !person.selected
    @@project.refresh()
  end
end
