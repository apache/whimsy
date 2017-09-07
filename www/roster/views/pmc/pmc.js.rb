#
# Show PMC members
#

class PMCMembers < Vue
  def initialize
    @committee = {}
  end

  def render
    _h2.pmc! 'PMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th if @@auth
          _th 'id'
          _th 'public name'
          _th 'starting date'
          _th 'status - click cell for actions'
        end
      end

      _tbody do
        roster.each do |person|
          _PMCMember auth: @@auth, person: person, committee: @@committee
        end
      end
    end
  end

  def roster
    result = []
    
    for id in @@committee.roster
      if @@committee.members.include?(id) or @@committee.ldap.include?(id)
        person = @@committee.roster[id]
        person.id = id
        result << person
      end
    end

    result.sort_by {|person| person.name}
  end
end

#
# Show a member of the PMC
#

class PMCMember < Vue
  def initialize
    @state = :closed
  end

  def render
    _tr do
      if @@auth
        _td do
           _input type: 'checkbox', checked: @@person.selected || false,
             onClick: -> {self.toggleSelect(@@person)}
        end
      end

      if @@committee.asfmembers.include? @@person.id
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" } }
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.name
      end

      _td @@person.date

      if @state == :open
        _td data_ids: @@person.id, onDoubleClick: self.select do 
          if not @@person.date
            # in LDAP but not in committee-info.txt
            _button.btn.btn_warning 'Remove from LDAP',
              data_action: 'remove pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} from LDAP?"

            unless @@committee.roster.keys().empty?
              _button.btn.btn_success 'Add to committee-info.txt',
                data_action: 'add info',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add to #{@@person.name} committee-info.txt"
            end
          elsif not @@person.ldap
             # in committee-info.txt but not in LDAP
            _button.btn.btn_success 'Add to LDAP',
              data_action: 'add pmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to LDAP?"

            _button.btn.btn_warning 'Remove from committee-info.txt',
              data_action: 'remove info',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: 
                "Remove #{@@person.name} from committee-info.txt?"
          else
            # in both LDAP and committee-info.txt
            if @@committee.committers.include? @@person.id
              _button.btn.btn_warning 'Remove only from PMC',
                data_action: 'remove pmc info',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} from the " +
                  "#{@@committee.display_name} PMC but leave as a committer?"

              _button.btn.btn_warning 'Remove as committer and from PMC',
                data_action: 'remove pmc info commit',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} as commiter and " +
                  "from the #{@@committee.display_name} PMC?"
            else
              _button.btn.btn_warning 'Remove from PMC',
                data_action: 'remove pmc info',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} from the " +
                  "#{@@committee.display_name} PMC?"

              _button.btn.btn_primary 'Add as a committer',
                data_action: 'add commit', 
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Grant #{@@person.name} committer access?"
            end
          end
        end
      elsif not @@person.date
        _td.issue.clickable 'not in committee-info.txt', onClick: self.select
      elsif not @@person.ldap
        _td.issue.clickable 'not in LDAP', onClick: self.select
      elsif not @@committee.committers.include? @@person.id
        _td.issue.clickable 'not in committer list', onClick: self.select
      elsif @@person.id == @@committee.chair
        _td.chair.clickable 'chair', onClick: self.select
      else
        _td.clickable '', onClick: self.select
      end
    end
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # toggle checkbox
  def toggleSelect(person)
    person.selected = !person.selected
    PMC.refresh()
  end
end
