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
# List of all other groups
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _banner breadcrumbs: {
    roster: '.',
    group: 'group/'
  }
  _body? do
    _whimsy_body(
      title: 'ASF Non-PMC Group list',
      breadcrumbs: {
        roster: '.',
        group: 'group/'
      }
    ) do
      # ********************************************************************
      # *                             Summary                              *
      # ********************************************************************
      _div.row do
        _div.col_md_5 do
          _div.well.well_sm do
            _table.counts do
              @groups.group_by(&:last).sort.each do |name, list|
                _tr do
                  _td list.count
                  _td name
                end
              end
            end
          end
        end
        _div.col_md_6 do
          _p do
            _ 'This data is for non-PMC groups, including unix groups and other LDAP groups; many of which are '
            _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
            _ ' private to the ASF.'
          end
        end
      end

      # ********************************************************************
      # *                          Complete list                           *
      # ********************************************************************
      _whimsy_panel_table(
        title: 'List of non-PMC Groups',
        helpblock: -> {
          _ 'Click on column headers to sort; click on name for '
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _' detail page.'
        }
      ) do
        _table.table.table_hover do
          _thead do
            _tr do
              _th.sorting_asc 'Name', data_sort: 'string-ins'
              _th 'Group type', data_sort: 'string'
            end
          end

          _tbody do
            @groups.each do |name, type|
              next if name == 'apldap'
              _tr_ do
                _td {_a name, href: "group/#{name}"}
                _td type
              end
            end
          end
        end
      end
    end
  end
  _script %{
    $(".table").stupidtable();
  }
end
