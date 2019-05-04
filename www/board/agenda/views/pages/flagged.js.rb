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

class Flagged < Vue
  def render
    first = true

    Agenda.index.each do |item|
      flagged = item.flagged_by || Pending.flagged.include?(item.attach)

      if not flagged and Minutes.started and item.attach =~ /^(\d+|[A-Z]+)$/
        flagged = !item.skippable
      end

      if flagged
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"

          flagged_by = Server.directors[item.flagged_by] || item.flagged_by
          _span.owner " flagged by: #{flagged_by}" if flagged_by
        end

        _AdditionalInfo item: item, prefix: true
      end
    end

    _em.comment 'None' if first
  end
end
