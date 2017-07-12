#
# Committers on the PMC
#

class PMCCommitters < React
  def render
    if
      @@committee.committers.keys().all? do |id|
        @@committee.roster[id] or @@committee.members.include? id
      end
    then
      _p 'All committers are members of the PMC'
    else
      _h2.committers! do
        _ 'Committers'
        _small ' (excluding PMC members above)'
      end
      _table.table.table_hover do
        _thead do
          _tr do
            _th 'id'
            _th 'public name'
            _th 'notes'
          end
        end

        _tbody do
          @committers.each do |person|
            next if @@committee.members.include? person.id
            next if @@committee.ldap[person.id]
            _PMCCommitter auth: @@auth, person: person, committee: @@committee
          end

          if @@auth
            _tr onClick: self.select do
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
# Show a committer
#

class PMCCommitter < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do

      if @@committee.asfmembers.include? @@person.id
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}"} }
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.name
      end

      if @state == :open
        _td data_ids: @@person.id do 
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
    @state = :closed if newprops.person.id != self.props.person.id
    @state = :open if @@person.date == 'pending'
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
