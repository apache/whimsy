#
# Show PPMC mentors
#

class PPMCMentors < Vue
  def initialize
    @ipmc = []
  end

  def render
    pending = [] 

    _h2.mentors! 'Mentors'
    _table.table.table_hover do
      _thead do
        _tr do
          _th if @@auth.ipmc
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
      end
    end
  end

  # compute roster
  def created()
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

  # add a person to the displayed list of PMC members
  def add(person)
    person.status = :pending
    @roster << person
  end
end

#
# Show a mentor of the PPMC
#

class PPMCMentor < Vue
  def render
    _tr do

      if @@auth.ipmc
        _td do
           _input type: 'checkbox', checked: @@person.selected || false,
             onChange: -> {self.toggleSelect(@@person)}
        end
      end

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
        if @@person.selected
	  if @@auth.ppmc
	    unless @@ppmc.owners.include? @@person.id
	      _button.btn.btn_primary 'Add to the PPMC',
		data_action: 'add ppmc committer',
		data_target: '#confirm', data_toggle: 'modal',
		data_confirmation: "Add #{@@person.name} as member of the " +
		  "#{@@ppmc.display_name} PPMC?"
	    end
	  end
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

  # toggle checkbox
  def toggleSelect(person)
    person.selected = !person.selected
    PPMC.refresh()
  end
end
