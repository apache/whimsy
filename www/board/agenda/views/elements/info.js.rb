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

class Info < Vue
  def render
    _dl.dl_horizontal class: @@position do
      _dt 'Attach'
      _dd @@item.attach

      if @@item.owner
        _dt 'Author'
        if (@@item.chair_email || '') .split('@')[1] == 'apache.org'
          chair = @@item.chair_email .split('@')[0]
          _dd do
            _a @@item.owner, 
              href: "https://whimsy.apache.org/roster/committer/#{chair}" 
          end
        else
          _dd @@item.owner
        end
      end

      if @@item.shepherd
        _dt 'Shepherd'
        _dd do
          if @@item.shepherd
            _Link text: @@item.shepherd, 
              href: "shepherd/#{@@item.shepherd.split(' ').first}"
          end
        end
      end

      if @@item.flagged_by and not @@item.flagged_by.empty?
        _dt 'Flagged By'
        _dd @@item.flagged_by.join(', ')
      end

      if @@item.approved and not @@item.approved.empty?
        _dt 'Approved By'
        _dd @@item.approved.join(', ')
      end

      if @@item.roster or @@item.prior_reports or @@item.stats
        _dt 'Links'

        if @@item.roster
          _dd { _a 'Roster', href: @@item.roster }
        end

        if @@item.prior_reports
          _dd { _a 'Prior Reports', href: @@item.prior_reports }
        end

        if @@item.stats
          _dd { _a 'Statistics', href: @@item.stats }
        end
      end
    end
  end
end
