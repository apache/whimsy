#
# Show a committee
#

class Committee < React
  def render
    auth = (@@auth.id == @committee.chair or @@auth.secretary or @@auth.root)

    # header
    _h1 do
      _a @committee.display_name, href: @committee.site
      _small " established #{@committee.established}" if @committee.established
    end

    _p @committee.description

    if auth
      _div.alert.alert_success 'Double click on a row to edit.  ' +
        "Double click on \u2795 to add."
    end

    # main content
    _PMCMembers auth: auth, committee: @committee
    _PMCCommitters auth: auth, committee: @committee

    # hidden form
    _PMCConfirm pmc: @committee.id, update: self.update if auth
  end

  # capture committee on initial load
  def componentWillMount()
    @committee = @@committee
  end

  # capture committee on subsequent loads
  def componentWillReceiveProps()
    @committee = @@committee
  end

  # update committee from conformation form
  def update(committee)
    @committee = committee
  end
end

#
# Show PMC members
#

class PMCMembers < React
  def initialize
    @state = :closed
  end

  def render
    _h2.pmc! 'PMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
          _th 'starting date'
        end
      end

      _tbody do
        @roster.each do |person|
          _PMCMember auth: @@auth, person: person, committee: @@committee
        end

        if @@auth
          _tr onDoubleClick: self.select do
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
  end

  # update props on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # compute roster
  def componentWillReceiveProps()
    roster = []
    
    for id in @@committee.roster
      person = @@committee.roster[id]
      person.id = id
      roster << person
    end

    for id in @@committee.ldap
      person = @@committee.roster[id]
      if person
        person.ldap = true
      else
        roster << {id: id, name: @@committee.ldap[id], ldap: true}
      end
    end

    @roster = roster.sort_by {|person| person.name}
  end

  # open search box
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # add a person to the displayed list of PMC members
  def add(person)
    person.date = 'pending'
    @roster << person
    @state = :closed
  end
end

#
# Committers on the PMC
#

class PMCCommitters < React
  def render
    if @@committee.committers.keys().all? {|id| @@committee.roster[id]}
      _p 'All committers are members of the PMC'
    else
      _h2.committers! 'Committers'
      _table.table.table_hover do
        _thead do
          _tr do
            _th 'id'
            _th 'public name'
          end
        end

        _tbody do
          @committers.each do |person|
            next if @@committee.roster[person.id]
            _PMCCommitter auth: @@auth, person: person, committee: @@committee
          end

          if @@auth
            _tr onDoubleClick: self.select do
              _td((@state == :open ? '' : "\u2795"), colspan: 3)
            end
          end
        end
      end

      if @state == :open
        _div.search_box do
          _CommitterSearch add: self.add
        end
      end
    end
  end

  # update props on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # compute list of committers
  def componentWillReceiveProps()
    committers = []
    
    for id in @@committee.committers
      committers << {id: id, name: @@committee.committers[id]}
    end

    @committers = committers.sort_by {|person| person.name}
  end

  # open search box
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # add a person to the displayed list of committers
  def add(person)
    person.date = 'pending'
    @committers << person
    @state = :closed
  end
end

#
# Show a member of the PMC
#

class PMCMember < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      _td {_a @@person.id, href: "committer/#{@@person.id}"}
      _td @@person.name
      _td @@person.date

      if @state == :open
        _td data_id: @@person.id do 
          if @@person.date == 'pending'
            _button.btn.btn_primary 'Add as a committer and to the PMC',
              # not added yet
              data_action: 'add pmc commit',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@committee.display_name} PMC and grant committer access?"

            _button.btn.btn_warning 'Add to PMC only', data_target: '#confirm',
              data_action: 'add pmc', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@committee.display_name} PMC?"
          elsif not @@person.date
            # in LDAP but not in committee-info.txt
            _button.btn.btn_warning 'Remove from LDAP',
              data_action: 'remove pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} from LDAP?"

            _button.btn.btn_success 'Add to committee-info.txt',
              disabled: true,
              data_confirmation: "Add to #{@@person.name} committee-info.txt"
          elsif not @@person.ldap
             # in committee-info.txt but not in ldap
            _button.btn.btn_success 'Add to LDAP',
              data_action: 'add pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to LDAP?"

            _button.btn.btn_warning 'Remove from committee-info.txt',
              disabled: true,
              data_confirmation: 
                "Remove #{@@person.name} from committee-info.txt?"
          else
            # in both LDAP and committee-info.txt
            _button.btn.btn_warning 'Remove from PMC',
              data_action: 'remove pmc commit', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} from the " +
                "#{@@committee.display_name} PMC?"

            if not @@committee.committers[@@person.id]
              _button.btn.btn_primary 'Add as a committer',
                data_action: 'add commit', 
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Grant #{@@person.name} committer access?"
            end
          end
        end
      elsif not @@person.date
        _td.issue 'not in committee-info.txt'
      elsif not @@person.ldap
        _td.issue 'not in LDAP'
      elsif not @@committee.committers[@@person.id]
        _td.issue 'not in committer list'
      elsif @@person.id == @@committee.chair
        _td.chair 'chair'
      else
        _td ''
      end
    end
  end

  # update props on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # automatically open pending entries
  def componentWillReceiveProps(newprops)
    @state = :closed if self.person != newprops.person
    @state = :open if @@person.date == 'pending'
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Show a committer
#

class PMCCommitter < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      _td {_a @@person.id, href: "committer/#{@@person.id}"}
      _td @@person.name

      if @state == :open
        _td data_id: @@person.id do 
          if @@person.date == 'pending'
            _button.btn.btn_primary 'Add as a committer only',
              data_action: 'add commit', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Grant #{@@person.name} committer access?"

            _button.btn.btn_success 'Add as a committer and to the PMC',
              data_action: 'add pmc commit', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                 "#{@@committee.display_name} PMC and grant committer access?"
          else
            _button.btn.btn_warning 'Remove as Committer',
              data_action: 'remove commit', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} as a Committer?"

            _button.btn.btn_primary 'Add to PMC',
              data_action: 'add pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@committee.display_name} PMC?"
          end
        end
      else
        _td ''
      end
    end
  end

  # update props on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # automatically open pending entries
  def componentWillReceiveProps(newprops)
    @state = :closed if self.person != newprops.person
    @state = :open if @@person.date == 'pending'
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

class PMCConfirm < React
  def initialize
    @text = 'text'
    @color = 'btn-default'
    @button = 'OK'
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
            _p @text
          end

          _div.modal_footer do
            _button.btn.btn_default 'Cancel', data_dismiss: 'modal'
            _button.btn @button, class: @color, onClick: self.post
          end
        end
      end
    end
  end

  def componentDidMount()
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
    # parse action extracted from the button
    targets = @action.split(' ')
    action = targets.shift()

    # construct arguments to fetch
    args = {
      method: 'post',
      credentials: 'include',
      headers: {'Content-Type' => 'application/json'},
      body: {pmc: @@pmc, id: @id, action: action, targets: targets}.inspect
    }

    fetch('actions/committee', args).then {|response|
      content_type = response.headers.get('content-type') || ''
      if response.status == 200 and content_type.include? 'json'
        response.json().then do |json|
          @@update.call(json)
        end
      else
        alert "#{response.status} #{response.statusText}"
      end
      jQuery('#confirm').modal(:hide)
    }.catch {|error|
      alert errror
      jQuery('#confirm').modal(:hide)
    }
  end
end
