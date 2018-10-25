#
# Show PPMC members
#

class PPMCMembers < Vue
  def render
    _h2.ppmc! 'PPMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th if @@auth.ppmc
          _th 'id', data_sort: 'string'
          _th 'githubUsername', data_sort: 'string'
          _th.sorting_asc 'public name', data_sort: 'string-ins'
          _th 'notes'
        end
      end

      _tbody do
        roster.each do |person|
          next if @@ppmc.mentors.include? person.id
          _PPMCMember auth: @@auth, person: person, ppmc: @@ppmc
        end
      end
    end
  end

  def mounted()
    jQuery('.table', $el).stupidtable()
  end

  # compute roster
  def roster
    result = []
    
    @@ppmc.owners.each do |id|
      person = @@ppmc.roster[id]
      person.id = id
      result << person
    end

    result.sort_by {|person| person.name}
  end
end

#
# Show a member of the PPMC
#

class PPMCMember < Vue
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
        _td @@person.githubUsername
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.githubUsername
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
    @@ppmc.refresh()
  end
end
