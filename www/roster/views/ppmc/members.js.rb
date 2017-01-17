#
# Show PPMC members
#

class PPMCMembers < React
  def initialize
    @ppmc = {}
    @state = :closed
  end

  def render
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
          _PPMCMember auth: @@auth, person: person, ppmc: @@ppmc
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
       _CommitterSearch add: self.add, exclude: @roster.map {|person| person.id}
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
    
    for id in @@ppmc.roster
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
    person.status = 'pending'
    @roster << person
    @state = :closed
  end
end

#
# Show a member of the PMC
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
        
      _td do
        if @state == :open
          if @@person.status == 'pending'
            _button.btn.btn_primary 'Add to the PPMC',
              data_action: 'add',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@ppmc.display_name} PPMC?"
          else
            _button.btn.btn_warning 'Remove from the PPMC',
              data_action: 'remove',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} from the " +
                "#{@@ppmc.display_name} PPMC?"
          end
        elsif @@person.status == 'pending'
          _span'pending'
        elsif @@ppmc.mentors.include? @@person.id
          _span.chair 'mentor'
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
    @state = :closed if @ppmc and newprops.ppmc.id != @ppmc.id
    @state = :open if @@person.status == 'pending'
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
