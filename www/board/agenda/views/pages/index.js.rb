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
# Overall Agenda page: simple table with one row for each item in the index
#

class Index < Vue
  def render
    _header do
      _h1 'ASF Board Agenda'
    end

    _table.table_bordered.agenda do
      _thead do
        _th 'Attach'
        _th 'Title'
        _th 'Owner'
        _th 'Shepherd'
      end

      started = Minutes.started
      _tbody Agenda.index do |row|
        _tr class: row.color do
          _td row.attach

          # once meeting has started, link to flagged queue for flagged items
          if started and row.attach =~ /^(\d+|[A-Z]+)$/ and !row.skippable
            _td { _Link text: row.title, href: 'flagged/' + row.href }
          else
            _td { _Link text: row.title, href: row.href }
          end

          _td row.owner || row.chair_name
          _td do
            if row.shepherd
              _Link text: row.shepherd,
                href: "shepherd/#{row.shepherd.split(' ').first}"
            end
          end
        end
      end
    end
  end
end
