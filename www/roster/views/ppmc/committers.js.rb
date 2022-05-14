#
# Committers on the PPMC
#

class PPMCCommitters < Vue
  def render
    pending = []

    _ ' ' # Not sure why, but without this the H2 elements are not generated

    if
      @@ppmc.committers.all? do |id|
        @@ppmc.owners.include? id
      end
    then
      _h2.committers! 'Committers (' + committers.length + ')'
      _p 'All committers are members of the PPMC'
    else
      _h2.committers! do
        _ 'Committers (' + committers.length + ')'
        _small ' (the listing excludes PPMC members above)'
      end
      _p 'Click on column name to sort'
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
          committers.each do |person|
            next if @@ppmc.owners.include? person.id
            _PPMCCommitter auth: @@auth, person: person, ppmc: @@ppmc
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

                _button.btn.btn_success 'Add all as committers',
                  data_action: 'add ppmc committer',
                  data_target: '#confirm', data_toggle: 'modal',
                  data_confirmation: "Add #{list} as committers for " +
                    "#{@@ppmc.display_name} PPMC?"
              end
            end
          end
        end
      end
    end
  end

  def mounted()
    jQuery('.table', $el).stupidtable()
  end

  # compute list of committers
  def committers
    result = []

    @@ppmc.committers.each do |id|
      person = @@ppmc.roster[id]
      person.id = id
      result << person
    end

    result.sort_by {|person| person.name}
  end
end

#
# Show a committer
#

class PPMCCommitter < Vue
  def render
    _tr do

      if @@auth.ppmc
        _td do
           _input type: 'checkbox', checked: @@person.selected || false,
             onChange: -> {self.toggleSelect(@@person)}
        end
      end

      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}"} }
        _td @@person.githubUsername
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.githubUsername
        _td @@person.name
      end

      if @@person.selected
        _td data_ids: @@person.id do
          if @@auth.ipmc and not @@person.icommit
            _button.btn.btn_primary 'Add as an incubator committer',
              data_action: 'add icommit',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} as a committer " +
                "for the incubator PPMC?"
          end
        end
      elsif not @@person.icommit
        _span.issue 'not listed as an incubator committer'
      else
        _td ''
      end
    end
  end

  # toggle checkbox
  def toggleSelect(person)
    person.selected = !person.selected
    @@ppmc.refresh()
  end
end
