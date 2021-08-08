#
# Show Committee members
#

class NonPMCMembers < Vue
  def initialize
    @nonpmc = {}
    @committers = []
  end

  def render
    _h2.pmc! 'Committee (' + roster.length + ')'
    _p 'Click on column name to sort'
    unless @@nonpmc.hasLDAP
      _p '** N.B. The status column does not show LDAP discrepancies because the committee does not have a standard LDAP setup **'
    end
    _table.table.table_hover do
      _thead do
        _tr do
          _th if @@auth
          _th 'id', data_sort: 'string'
          _th 'githubUsername', data_sort: 'string'
          _th.sorting_asc 'public name', data_sort: 'string-ins'
          _th 'starting date', data_sort: 'string'
          _th 'status - click cell for actions', data_sort: 'string'
        end
      end

      _tbody do
        roster.each do |person|
          _NonPMCMember auth: @@auth, person: person, nonpmc: @@nonpmc
        end
      end
    end
  end

  def mounted()
    jQuery('.table', $el).stupidtable()
  end

  def roster
    result = []

    for id in @@nonpmc.roster
      if @@nonpmc.members.include?(id) or @@nonpmc.ldap.include?(id)
        person = @@nonpmc.roster[id]
        person.id = id
        result << person
      end
    end

    result.sort_by {|person| person.name}
  end
end

#
# Show a member of the Committee
#

class NonPMCMember < Vue
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
      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" }
              _a ' (*)', href: "nonpmc/#{@@nonpmc.id}#crosscheck" if @@person.notSubbed and @@nonpmc.analysePrivateSubs
            }
        _td @@person.githubUsername
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}"
              _a ' (*)', href: "nonpmc/#{@@nonpmc.id}#crosscheck" if @@person.notSubbed and @@nonpmc.analysePrivateSubs
            }
        _td @@person.githubUsername
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

            unless @@nonpmc.roster.keys().empty?
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
            if @@nonpmc.committers.include? @@person.id
              _button.btn.btn_warning 'Remove only from Committee',
                data_action: 'remove pmc info',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} from the " +
                  "#{@@nonpmc.display_name} Committee but leave as a committer?"

              _button.btn.btn_warning 'Remove as committer and from Committee',
                data_action: 'remove pmc info commit',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} as committer and " +
                  "from the #{@@nonpmc.display_name} Committee?"
            else
              _button.btn.btn_warning 'Remove from Committee',
                data_action: 'remove pmc info',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Remove #{@@person.name} from the " +
                  "#{@@nonpmc.display_name} Committee?"

              _button.btn.btn_primary 'Add as a committer',
                data_action: 'add commit',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Grant #{@@person.name} committer access?"
            end
          end
        end
      elsif not @@person.date
        _td.issue.clickable 'not in committee-info.txt', onClick: self.select
      elsif @@nonpmc.hasLDAP and not @@person.ldap
        _td.issue.clickable 'not in LDAP', onClick: self.select
      elsif @@nonpmc.hasLDAP and not @@nonpmc.committers.include? @@person.id
        _td.issue.clickable 'not in committer list', onClick: self.select
      elsif @@person.id == @@nonpmc.chair
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
    @@nonpmc.refresh()
  end
end
