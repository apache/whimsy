#
# Show PMC members
#

class PMCMembers < React
  def initialize
    @committee = {}
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
              data_action: 'add pmc info commit',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@committee.display_name} PMC and grant committer access?"

            _button.btn.btn_warning 'Add to PMC only', data_target: '#confirm',
              data_action: 'add pmc info', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@committee.display_name} PMC?"
          elsif not @@person.date
            # in LDAP but not in committee-info.txt
            _button.btn.btn_warning 'Remove from LDAP',
              data_action: 'remove pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} from LDAP?"

            _button.btn.btn_success 'Add to committee_info.txt',
              data_action: 'add info',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add to #{@@person.name} committee_info.txt"
          elsif not @@person.ldap
             # in committee-info.txt but not in ldap
            _button.btn.btn_success 'Add to LDAP',
              data_action: 'add pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to LDAP?"

            _button.btn.btn_warning 'Remove from committee_info.txt',
              data_action: 'remove info',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: 
                "Remove #{@@person.name} from committee_info.txt?"
          else
            # in both LDAP and committee-info.txt
            _button.btn.btn_warning 'Remove from PMC',
              data_action: 'remove pmc info commit', 
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
        _td.issue 'not in committee_info.txt'
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
    @state = :closed if @committee and newprops.committee.id != @committee.id
    @state = :open if @@person.date == 'pending'
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
