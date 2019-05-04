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
# Committers on the PMC
#

class PMCCommitters < Vue
  def render
    if
      @@committee.committers.all? do |id|
        @@committee.members.include? id
      end
    then
      _h2.committers! 'Committers (' + committers.length + ')' 
      _p 'All committers are members of the PMC'
    else
      _h2.committers! do
        _ 'Committers (' + committers.length + ')' 
        _small ' (the listing excludes PMC members above)'
      end
      _p 'Click on column name to sort'
      _table.table.table_hover do
        _thead do
          _tr do
            _th if @@auth
            _th 'id', data_sort: 'string'
            _th 'githubUsername', data_sort: 'string'
            _th.sorting_asc 'public name', data_sort: 'string-ins'
          end
        end

        _tbody do
          committers.each do |person|
            next if @@committee.members.include? person.id
            next if @@committee.ldap.include? person.id
            _PMCCommitter auth: @@auth, person: person, committee: @@committee
          end
        end
      end
    end
  end

  def mounted()
    jQuery('.table', $el).stupidtable()
  end

  # compute list of committers
  def committers
    result = []
    
    @@committee.committers.each do |id|
      person = @@committee.roster[id]
      person.id = id
      result << person
    end

    result.sort_by {|person| person.name}
  end
end

#
# Show a committer
#

class PMCCommitter < Vue
  def render
    _tr do
      if @@auth
        _td do
           _input type: 'checkbox', checked: @@person.selected || false,
             onChange: -> {self.toggleSelect(@@person)}
        end
      end

      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}"} }
        _td @@person.githubUsername
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.githubUsername
        _td @@person.name
      end
    end
  end

  # toggle checkbox
  def toggleSelect(person)
    person.selected = !person.selected
    @@committee.refresh()
  end
end
