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
# Landing page
#
PAGETITLE = "ASF Roster Tool" # Wvisible:projects

_html do
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      title: PAGETITLE,
      breadcrumbs: {
        roster: '.'
      }
    ) do
      _table.counts do

        ### committers

        _tr do
          _td do
            _a @committers.length, href: 'committer/'
          end

          _td do
            _a 'Committers', href: 'committer/'
          end

          _td do
            _ 'Search for committers by name, user id, or email address'
            _ ' (includes '
            _ @committers.select{|c| c.inactive?}.length
            _ ' inactive accounts)'
          end
        end

        ### members

        _tr do
          _td do
            _a @members.length, href: 'members'
          end

          _td do
            _a 'Members', href: 'members'
          end

          _td 'Active ASF members'
        end

        ### PMCs

        _tr do
          _td do
            _a @committees.length, href: 'committee/'
          end

          _td do
            _a 'PMCs', href: 'committee/'
          end

          _td 'Active projects at the ASF'
        end

        _tr do
          _td do
            _a @nonpmcs.length, href: 'nonpmc/'
          end

          _td do
            _a 'nonPMCs', href: 'nonpmc/'
          end

          _td 'ASF Committees (non-PMC)'
        end

        ### Podlings

        _tr do
          _td do
            _a @podlings.select {|podling| podling.status == 'current'}.length,
              href: 'ppmc/'
          end

          _td do
            _a 'Podlings', href: 'ppmc/'
          end

          _td! do 
            _span 'Active podlings at the ASF ('
            _a @podlings.length, href: 'podlings'
            _span ' total)'
          end

        end

        ### Groups

        _tr do
          _td do
            _a @groups.length, href: 'group/'
          end

          _td do
            _a 'Groups', href: 'group/'
          end

          _td 'Assorted other groups from various sources'
        end

      end

      person = ASF::Person.find(env.user)
      if person.asf_member? or ASF.pmc_chairs.include? person
        _hr
        _p do
          _a 'Organization Chart ', href: 'orgchart/'
          _span.glyphicon.glyphicon_lock :aria_hidden, class: "text-primary", aria_label: "ASF Members and Officers"
        end
      end
    end
  end
end
