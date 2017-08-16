#
# Show PPMC members
#

class PPMCMembers < React
  def render
    pending = [] 

    _h2.ppmc! 'PPMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th if @@auth.ppmc
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

  # add a person to the displayed list of PMC members
  def add(person)
    person.status = :pending
    @roster << person
  end
end

#
# Show a member of the PPMC
#

class PPMCMember < React
  def render
    _tr do

      if @@auth.ppmc
        _td do
           _input type: 'checkbox', checked: @@person.selected || false,
             onChange: -> {self.toggleSelect(@@person)}
        end
      end

      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" } }
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.name
      end
        
      _td data_ids: @@person.id do
        if @@person.selected
	  if @@auth.ipmc and not @@person.icommit
	    _button.btn.btn_primary 'Add as an incubator committer',
	      data_action: 'add icommit',
	      data_target: '#confirm', data_toggle: 'modal',
	      data_confirmation: "Add #{@@person.name} as a commiter " +
		"for the incubator PPMC?"
	  end

	  unless @@ppmc.committers.include? @@person.id
	    _button.btn.btn_primary 'Add as committer',
	      data_action: 'add committer',
	      data_target: '#confirm', data_toggle: 'modal',
	      data_confirmation: "Add #{@@person.name} as a committer " +
		"for the #{@@ppmc.display_name} PPMC?"
	  end
        elsif not @@ppmc.committers.include? @@person.id
          _span.issue 'not listed as a committer'
        elsif not @@person.icommit
          _span.issue 'not listed as an incubator committer'
        end
      end
    end
  end

  # toggle checkbox
  def toggleSelect(person)
    person.selected = !person.selected
    PPMC.refresh()
  end
end
