#
# Show PPMC members
#

class PPMCMembers < React
  def initialize
    @state = :closed
  end

  def render
    pending = [] 

    _h2.pmc! 'PPMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
          _th 'notes'
        end
      end

      _tbody do
        @roster.each do |person|
          next if @@ppmc.mentors.include? person.id
          _PPMCMember auth: @@auth, person: person, ppmc: @@ppmc
          pending << person.id if person.status == :pending
        end

        if pending.length > 1
          _tr do
            _td colspan: 2
            _td data_ids: pending.join(',') do

              # produce a list of ids to be added
              if pending.length == 2
                list = "#{pending[0]} and #{pending[1]}"
              else
                list = pending[0..-2].join(', ') + ", and " +  pending[-1]
              end

              _button.btn.btn_success 'Add all to the PPMC',
                data_action: 'add ppmc committer',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{list} to the " +
                  "#{@@ppmc.display_name} PPMC?"
            end
          end
        end

        if @@auth and not @@ppmc.roster.keys().empty?
          _tr onClick: self.select do
            _td((@state == :open ? '' : "\u2795"), colspan: 4)
          end
        end
      end
    end

    if @state == :open
      _div.search_box do
        _CommitterSearch add: self.add, multiple: true,
          exclude: @roster.map {|person| person.id unless person.issue}
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
    
    @@ppmc.owners.each do |id|
      person = @@ppmc.roster[id]
      person.id = id
      roster << person
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
    person.status = :pending
    @roster << person
    @state = :closed
  end
end

#
# Show a member of the PPMC
#

class PPMCMember < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do

      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" } }
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.name
      end
        
      _td data_ids: @@person.id do
        if @state == :open
          if @@person.status == :pending
            # not added yet
            _button.btn.btn_primary 'Add as a committer and to the PPMC',
              data_action: 'add ppmc committer',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@ppmc.display_name} PPMC and grant committer access?"

            if @@ppmc.committers.all? {|person| @@ppmc.owners.include? person}
              _button.btn.btn_warning 'Add as a committer only',
                data_action: 'add committer',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{@@person.name} to the " +
                  "#{@@ppmc.display_name} PPMC and grant committer access?"
            end
          else
            if @@ppmc.committers.include? @@person.id
              _button.btn.btn_warning 'Remove as committer and from the PPMC',
                data_action: 'remove ppmc committer',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} as a commiter " +
                  "and from the #{@@ppmc.display_name} PPMC?"
            else
              _button.btn.btn_primary 'Add as committer',
                data_action: 'add committer',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{@@person.name} as a committer " +
                  "for the #{@@ppmc.display_name} PPMC?"
            end

            _button.btn.btn_warning 'Remove only from the PPMC',
              data_action: 'remove ppmc',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} from the " +
                "#{@@ppmc.display_name} PPMC but leave as a committer?"
          end
        elsif @@person.status == :pending
          _span 'pending'
        elsif not @@ppmc.committers.include? @@person.id
          _span.issue 'not listed as a committer'
        elsif not @@person.icommit
          _span.issue 'not listed as an incubator committer'
        end
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
    @state = :open if @@person.status == :pending
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
