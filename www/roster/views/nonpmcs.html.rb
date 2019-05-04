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
# List of committees
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _whimsy_body(
    title: 'ASF Committees Listing (non-PMC)',
    breadcrumbs: {
      roster: '.',
      nonpmc: 'nonpmc/'
    }
  ) do
    _p do
      _ 'A full list of Apache committees that are not PMCs; click on the name for a detail page about that committee.'
      _ '(from committee-info.txt)'
      _br
      _ 'Other groups of various kinds '
      _a href: '/roster/group/' do
        _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
        _ 'are listed privately.'
      end
    end
    _p 'Click on column names to sort.'

    _table.table.table_hover do
      _thead do
        _tr do
          _th.sorting_asc 'Name', data_sort: 'string-ins'
          _th 'Chair(s)', data_sort: 'string'
          _th 'Description', data_sort: 'string'
        end
      end

      @nonpmcs.sort_by {|pmc| pmc.display_name.downcase}.each do |pmc|
        _tr_ do
          _td do
            _a pmc.display_name, href: "nonpmc/#{pmc.name}"
          end

          _td do
            pmc.chairs.each_with_index do |chair, index|
              _span ', ' unless index == 0

              if @members.include? chair[:id]
                _b! {_a chair[:name], href: "committer/#{chair[:id]}"}
              else
                _a chair[:name], href: "committer/#{chair[:id]}"
              end
            end
          end

#          if not pmc.established
#            _td.issue 'Not in committee-info.txt'
#          else
            _td pmc.description
#          end
        end
      end
    end
  end
  _script %{
    $(".table").stupidtable();
  }
end
