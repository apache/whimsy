#
# Show a committee
#

class Committee < React
  def render
    auth = (@@auth.id == @@committee.chair or @@auth.secretary)

    # header
    _h1 do
      _a @@committee.display_name, href: @@committee.site
      _span ' '
      _small "established #{@@committee.established}"
    end

    _p @@committee.description

    _div.alert.alert_success 'Double click on a row to edit' if auth

    # main content
    _PMCMembers auth: @@auth, committee: @@committee
    _PMCCommitters auth: @@auth, committee: @@committee

    # hidden form
    _PMCConfirm if @@auth
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

        _PMCMember auth: @@auth, person: person, committee: @@committee
      end

      if @@auth
        _tr onDoubleClick: self.select do
          _td((@state == :open ? '' : '+'), colspan: 4)
        end
      end
    end

   if @state == :open
     _div.search_box do
       _CommitterSearch add: self.add
     end
   end
  end

  def select
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  def add(person)
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
          _PMCCommitter auth: @@auth, person: {id: id, name: committers[id]},
            committee: @@committee
        end

        if @@auth
          _tr onDoubleClick: self.select do
            _td((@state == :open ? '' : '+'), colspan: 4)
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

  def select
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  def add(person)
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
