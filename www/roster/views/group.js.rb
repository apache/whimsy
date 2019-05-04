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
# Show a committee
#

class Group < Vue
  def initialize
    @state = :closed
    @pending = {}
  end

  def render
    group = @group
    members = group.members.keys().sort_by {|id| group.members[id]}

    if group.type == 'LDAP auth group' or group.id == 'asf-secretary'
      auth = (members.include? @@auth.id or @@auth.secretary or @@auth.root)
    elsif group.id == 'hudson-jobadmin'
      auth = @@auth.pmc_chair or group.owners.include? @@auth.id
    else
      auth = false 
    end

    # header
    _h1 do
      _span group.id
      _span.note " (#{group.type}) #{group.dn}"
    end

    # usage information for authenticated users (group members, etc.)
    if auth
      _div.alert.alert_success do
        _span 'Double click on a row to edit.'
        _span "  Click on \u2795 to add."
      end
    end

    # list of members
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
        end
      end

      _tbody do
        members.each do |id|
          _GroupMember id: id, name: group.members[id], auth: auth, 
            pending: false
        end

        for id in @pending
          _GroupMember id: id, name: @pending[id], auth: auth, 
            pending: true
        end

        if auth
          _tr onClick: self.select do
            _td((@state == :open ? '' : "\u2795"), colspan: 4)
          end
        end
      end
    end

    if @state == :open
      _div.search_box do
        _CommitterSearch add: self.add
      end
    end

    _GroupConfirm group: group, update: self.update if auth
  end

  # capture group on initial load
  def created()
    self.update(@@group)
  end

  # update group from conformation form
  def update(group)
    # remove members of the group from pending lists
    for id in group.members
      @pending.delete(id)
    end

    # capture group
    @group = group
  end

  # open search box
  def select()
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # add a person to the displayed list of group members
  def add(person)
    @pending[person.id] = person.name
    @state = :closed
  end
end

#
# Show a member of the Group
#

class GroupMember < Vue
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      _td {_a @@id, href: "committer/#{@@id}"}
      _td @@name

      _td data_id: @@id do
        if @@pending
          _button.btn.btn_success 'Add to Group', data_action: 'add',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Add #{@@name} to"
        elsif @state == :open
          _button.btn.btn_warning 'Remove from Group', data_action: 'remove',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Remove #{@@name} from"
        else
          _span ''
        end
      end
    end
  end

  # update id on initial load
  def mounted()
    @id = @@id
  end

  # automatically close row when id changes
  def beforeUpdate()
    @state = :closed if @id != @@id and @state != :closed
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Confirmation dialog
#

class GroupConfirm < Vue
  def initialize
    @text = 'text'
    @color = 'btn-default'
    @button = 'OK'
    @disabled = false
  end

  def render
    _div.modal.fade.confirm! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title 'Confirm Request'
          end

          _div.modal_body do
            _p do 
              _span "#{@text} the "
              _code @@group.id
              _span " #{@@group.type}?"
            end
          end

          _div.modal_footer do
            _span.status 'Processing request...' if @disabled
            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled
            _button.btn @button, class: @color, onClick: self.post,
              disabled: @disabled
          end
        end
      end
    end
  end

  def mounted()
    jQuery('#confirm').on('show.bs.modal') do |event|
      button = event.relatedTarget
      @id = button.parentNode.dataset.id
      @action = button.dataset.action
      @text = button.dataset.confirmation
      @color = button.classList[1]
      @button = button.textContent
    end
  end

  def post()
    # identify the action
    if @@group.type == 'LDAP auth group'
      action = 'actions/authgroup'
    elsif @@group.type == 'LDAP service'
      action = 'actions/service'
    elsif @@group.type == 'LDAP app group'
      action = 'actions/appgroup'
    else
      alert "unsupported group type: #{@@group.type}"
      return
    end

    # construct arguments to fetch
    args = {
      method: 'post',
      credentials: 'include',
      headers: {'Content-Type' => 'application/json'},
      body: {group: @@group.id, id: @id, action: @action}.inspect
    }

    @disabled = true
    Polyfill.require(%w(Promise fetch)) do
      fetch(action, args).then {|response|
        content_type = response.headers.get('content-type') || ''
        if response.status == 200 and content_type.include? 'json'
          response.json().then do |json|
            @@update.call(json)
          end
        else
          alert "#{response.status} #{response.statusText}"
        end
        jQuery('#confirm').modal(:hide)
        @disabled = false
      }.catch {|error|
        alert error
        jQuery('#confirm').modal(:hide)
        @disabled = false
      }
    end
  end
end
