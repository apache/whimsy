#
# Show PPMC mentors
#

class PPMCMentors < React
  def initialize
    @state = :closed
    @ipmc = []
  end

  def render
    pending = [] 

    _h2.mentors! 'Mentors'
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
          _PPMCMentor auth: @@auth, person: person, ppmc: @@ppmc
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

              _button.btn.btn_success 'Add all as mentors',
                data_action: 'add ppmc committer mentor',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{list} to the " +
                  "#{@@ppmc.display_name} PPMC?"
            end
          end
        end

        if @@auth and @@auth.ipmc and not @@ppmc.roster.keys().empty?
          _tr onClick: self.select do
            _td((@state == :open ? '' : "\u2795"), colspan: 4)
          end
        end
      end
    end

    if @state == :open
      _div.search_box do
        _CommitterSearch add: self.add, include: @ipmc, multiple: true,
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
    
    @@ppmc.mentors.each do |id|
      person = @@ppmc.roster[id]
      person.id = id
      roster << person
    end

    @roster = roster.sort_by {|person| person.name}
  end

  # fetch IPMC list
  def componentDidMount()
    return unless @@auth and @@auth.ipmc
    Polyfill.require(%w(Promise fetch)) do
      fetch('committee/incubator.json', credentials: 'include').then {|response|
	if response.status == 200
	  response.json().then do |json|
	    @ipmc = json.roster.keys()
	  end
	else
	  console.log "IPMC #{response.status} #{response.statusText}"
	end
      }.catch {|error|
	console.log "IPMC #{errror}"
      }
    end
  end

  # open search box
  def select()
    return unless @@auth and @@auth.ipmc
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
# Show a mentor forthe PPMC
#

class PPMCMentor < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do

      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" } }
        _td { _b @@person.name }
      elsif @@person.name
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.name
      else
        _td @@person.id
        _td @@person.name
      end
        
      _td data_ids: @@person.id do
        if @state == :open
          if @@person.status == :pending
            if @@auth.ppmc
              _button.btn.btn_primary 'Add as a mentor',
                data_action: 'add mentor ppmc committer',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{@@person.name} as a mentor to the " +
                  "#{@@ppmc.display_name} PPMC?"
            else
              _button.btn.btn_primary 'Add only as a mentor',
                data_action: 'add mentor',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{@@person.name} as a mentor to the " +
                  "#{@@ppmc.display_name} PPMC?"
            end
          else
            if @@auth.ppmc
	      unless @@ppmc.owners.include? @@person.id
		_button.btn.btn_primary 'Add to the PPMC',
		  data_action: 'add ppmc committer',
		  data_target: '#confirm', data_toggle: 'modal',
		  data_confirmation: "Add #{@@person.name} as member of the " +
		    "#{@@ppmc.display_name} PPMC?"
	      end

	      _button.btn.btn_warning 'Remove as a mentor and from the PMC',
		data_action: 'remove mentor ppmc committer',
		data_target: '#confirm', data_toggle: 'modal',
		data_confirmation: "Remove #{@@person.name} as a mentor, " +
		  "PPMC member, and committer from the " +
                  "#{@@ppmc.display_name} PPMC?"
            end

            _button.btn.btn_warning 'Remove only as a mentor',
              data_action: 'remove mentor',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} as a mentor from " +
                "the #{@@ppmc.display_name} PPMC?"
          end
        elsif @@person.status == :pending
          _span 'pending'
        elsif not @@person.name
          _span.issue 'invalid user'
        elsif not @@ppmc.owners.include? @@person.id
          _span.issue 'not on the PPMC'
        elsif not @@person.ipmc
          _span.issue 'not on the IPMC'
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
    return unless @@auth and @@auth.ipmc
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
