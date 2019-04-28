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
# A page showing all flagged reports
#

class Missing < Vue
  def initialize
    @checked = {}
  end

  # update check marks based on current Index
  def beforeMount()
    Agenda.index.each do |item|
      @checked[item.title] = true unless defined? @checked[item.title]
    end
  end

  def render
    first = true

    Agenda.index.each do |item|
      if item.missing and item.owner and item.nonresponsive
        _h2 'Non responsive PMCs' if first

        _h3 class: item.color do
          if item.attach =~ /^[A-Z]+/
            _input.inactive type: 'checkbox', name: 'selected', 
              value: item.title, checked: @checked[item.title]
          end

          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"

          if item.flagged_by
            flagged_by = Server.directors[item.flagged_by] || item.flagged_by
            _span.owner " flagged by: #{flagged_by}"
          end
        end

        _AdditionalInfo item: item, prefix: true
      end
    end

    _h2 'Other missing reports' unless first

    Agenda.index.each do |item|
      if item.missing and item.owner and not item.nonresponsive
        _h3 class: item.color do
          if item.attach =~ /^[A-Z]+/
            _input.active type: 'checkbox', name: 'selected',
              value: item.title, checked: @checked[item.title]
          end

          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"

          if item.flagged_by
            flagged_by = Server.directors[item.flagged_by] || item.flagged_by
            _span.owner " flagged by: #{flagged_by}"
          end
        end

        _AdditionalInfo item: item, prefix: true
      end
    end

    _em.comment 'None' if first
  end
end
