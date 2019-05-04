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
# Modify People's role in a project
#

class PMCMod < Vue
  mixin ProjectMod
  options mod_tag: "pmcmod", mod_action: 'actions/committee'

  def initialize
    @people = []
  end

  def render
    _div.modal.fade.pmcmod! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title "Modify People's Roles in the " + 
              @@project.display_name + ' Project'
          end

          _div.modal_body do
            _div.container_fluid do
              _table.table do
                _thead do
                  _tr do
                    _th 'id'
                    _th 'name'
                  end
                end
                _tbody do
                  @people.each do |person|
                    _tr do
                      _td person.id
                      _td person.name
                    end
                  end
                end
              end
            end

            # add to PMC button is only shown if every person is not on the PMC
            if @people.all? {|person| !@@project.members.include? person.id}
              _p do
                _label do
                  _input type: 'checkbox', checked: @notice_elapsed
                  _a '72 hour board@ NOTICE',
                    href: 'https://www.apache.org/dev/pmc.html#notice_period'
                  _span ' period elapsed?'
                end
              end
            end
          end

          _div.modal_footer do
            _span.status 'Processing request...' if @disabled

            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled

            # show add to PMC button only if every person is not on the PMC
            if @people.all? {|person| !@@project.members.include? person.id}
              _button.btn.btn_primary "Add to PMC", 
                data_action: 'add pmc info',
                onClick: self.post, disabled: (@people.empty? or not @notice_elapsed)
            end

            # remove from all relevant locations
            remove_from = ['commit']
            if @people.any? {|person| @@project.members.include? person.id}
              remove_from << 'info'
            end
            if @people.any? {|person| @@project.ldap.include? person.id}
              remove_from << 'pmc'
            end

            _button.btn.btn_primary 'Remove from project', onClick: self.post,
              data_action: "remove #{remove_from.join(' ')}"

            if @people.all? {|person| @@project.members.include? person.id}
              _button.btn.btn_warning "Remove from PMC only", 
                data_action: 'remove pmc info',
                onClick: self.post
            end
          end
        end
      end
    end
  end
end
