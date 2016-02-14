#
# Show a committee
#

class Committee < React
  def render
    auth = (@@auth.id == @@committee.chair or @@auth.secretary)

    _h1 do
      _a @@committee.display_name, href: @@committee.site
      _span ' '
      _small "established #{@@committee.established}"
    end

    _p @@committee.description

    _div.alert.alert_success 'Double click on a row to edit' if auth

    _h2 'PMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
          _th 'starting date'
        end
      end

      roster = @@committee.roster

      for id in roster
        person = roster[id]
        person.id = id

        _PMCMember auth: auth, person: person, committee: @@committee
      end

      _PMCMemberAdd if auth
    end

    if @@committee.committers.keys().all? {|id| @@committee.roster[id]}
      _p 'All committers are members of the PMC'
    else
      _h2 'Committers'
      _table.table.table_hover do
        _thead do
          _tr do
            _th 'id'
            _th 'public name'
          end
        end

        committers = @@committee.committers

        for id in committers
          next if @@committee.roster[id]
          _PMCCommitter auth: auth, person: {id: id, name: committers[id]},
            committee: @@committee
        end

        _PMCCommitterAdd if auth
      end
    end

    _PMCConfirm if auth
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
        _td do 
          _button.btn.btn_warning 'Remove from PMC', data_target: '#confirm',
            data_toggle: 'modal',
            data_confirmation: "Remove #{@@person.name} from the " +
              "#{@@committee.display_name} PMC?"
        end
      elsif @@person.id == @@committee.chair
        _td.chair 'chair'
      else
        _td ''
      end
    end
  end

  def select
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Add a member to the PMC
#

class PMCMemberAdd < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      if @state == :open
        _td '+'
        _td { _input }
        _td colspan: 2 do
          _button.btn.btn_primary 'Add as a committer and to the PMC',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Add #{@@person.name} to the " +
              "#{@@committee.display_name} PMC and as a committer?"
          _button.btn.btn_warning 'Add to PMC only', data_target: '#confirm',
            data_toggle: 'modal',
            data_confirmation: "Add #{@@person.name} to the " +
              "#{@@committee.display_name} PMC?"
        end
      else
        _td '+', colspan: 4
      end
    end
  end

  def select
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
        _td do
          _button.btn.btn_warning 'Remove as Committer',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Remove #{@@person.name} as a Committer?"
          _button.btn.btn_primary 'Add to PMC',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Add #{@@person.name} to the " +
              "#{@@committee.display_name} PMC?"
        end
      else
        _td ''
      end
    end
  end

  def select
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Add a committer
#

class PMCCommitterAdd < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      if @state == :open
        _td '+'
        _td { _input }
        _td colspan: 2 do
          _button.btn.btn_success 'add as a committer only'
          _button.btn.btn_primary 'add as a committer and to the PMC'
        end
      else
        _td '+', colspan: 4
      end
    end
  end

  def select
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

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
            _button.btn.btn_default 'Cancel', data_dismiss:"modal"
            _button.btn @button, data_dismiss:"modal", class: @color
          end
        end
      end
    end
  end

  def componentDidMount()
    jQuery('#confirm').on('show.bs.modal') do |event|
      button = event.relatedTarget
      @text = button.dataset.confirmation
      @color = button.classList[1]
      @button = button.textContent
    end
  end
end
