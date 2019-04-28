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

class Help < Vue
  def render
    _h3 'Keyboard shortcuts'
    _dl.dl_horizontal do
      _dt 'left arrow'
      _dd 'previous page'

      _dt 'right arrow'
      _dd 'next page'

      _dt 'enter'
      _dd 'On Shepherd and Queue pages, go to the first report listed'

      _dt 'C'
      _dd 'Scroll to comment section (if any)'

      _dt 'I'
      _dd 'Toggle Info dropdown'

      _dt 'N'
      _dd 'Toggle Navigation dropdown'

      _dt 'A'
      _dd 'Navigate to the overall agenda page'

      _dt 'F'
      _dd 'Show flagged items'

      _dt 'M'
      _dd 'Show missing items'

      _dt 'Q'
      _dd 'Show queued approvals/comments'

      _dt 'S'
      _dd 'Show shepherded items (and action items)'

      _dt 'X'
      _dd 'Set the topic (a.k.a. mark the spot)'

      _dt '?'
      _dd 'Help (this page)'
    end

    _h3 'Color Legend'
    _ul do
      _li.missing 'Report missing, rejected, or has formatting errors'
      _li.available 'Report present, not eligible for pre-reviews'
      _li.ready 'Report present, ready for (more) review(s)'
      _li.reviewed 'Report has sufficient pre-approvals'
      _li.commented 'Report has been flagged for discussion'
    end

    _h3 'Change Role'
    _form.role! do
      %w(Secretary Director Guest).each do |role|
        _div do
          _input type: 'radio', name: 'role', value: role.downcase(),
            checked: role.downcase() == User.role, onChange: self.setRole
          _ role
        end
      end
    end

    _br
    _Link text: 'Insider Secrets', href: 'secrets'
  end

  def setRole(event)
    User.role = event.target.value
    Main.refresh()
  end
end
