#
# Show PPMC members
#

class PPMCMembers < Vue
  def render
    _h2.ppmc! 'PPMC (' + roster.length + ')'
    _p '(the listing below excludes mentors)'
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

    if @@ppmc.analysePrivateSubs
      _h4.crosscheck! 'Cross-check of private@ list subscriptions'
      _p {
        _ 'PPMC entries above with (*) do not appear to be subscribed to the private list.'
        _br
        _ 'This could be because the person is subscribed with an address that is not in their LDAP record'
      }
      # separate out the known ASF members and extract any matching committer details
      unknownSubs = @@ppmc.unknownSubs
      asfMembers = @@ppmc.asfMembers
      # Any unknown subscribers?
      if unknownSubs.length > 0
        _p {
          # We don't use the short-hand name: value syntax here to work-round Eclipse Ruby editor parsing bug
          _span.glyphicon.glyphicon_lock aria_hidden: true, :class => 'text-primary', 'aria-label' => 'ASF Members and private@ moderators'
          _ 'The following subscribers to the private list do not match the known emails for any of the existing PPMC (or ASF) members.'
          _br
          _ 'They could be PPMC (or ASF) members whose emails are not listed in their LDAP record.'
          _br
          _ 'Or they could be ex-PPMC members who are still subscribed.'
          _br
          _ '(Note that digest subscriptions are not currently included)'
          _br
          _br
          _ul {
            unknownSubs.each do |sub|
              person = sub['person']
              if person
                _li {
                  _ sub['addr']
                  _ ' '
                  _ person['name']
                  _ ' '
                  _a person['id'], href: "committer/#{person['id']}"
                }
              else
                _li {
                  _ sub['addr']
                  _ ' '
                  _ '(not recognised)'
                }
              end
            end
          }
        }
      end
      # Any ASF members?
      if asfMembers.length > 0
        _p {
          # We don't use the short-hand name: value syntax here to work-round Eclipse Ruby editor parsing bug
          _span.glyphicon.glyphicon_lock aria_hidden: true, :class => 'text-primary', 'aria-label' => 'ASF Members and private@ moderators'
          _ 'The following ASF members are also subscribed to the list.'
          _br
          _br
          _ul {
            asfMembers.each do |sub|
              person = sub['person']
              if person
                _li {
                  _strong {
                    _ sub['addr']
                    _ ' '
                    _ person['name']
                    _ ' '
                    _a person['id'], href: "committer/#{person['id']}"
                  }
                }
              end
            end
          }
        }
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
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" }
              _a ' (*)', href: "ppmc/#{@@ppmc.id}#crosscheck" if @@person.notSubbed and @@ppmc.analysePrivateSubs
            }
        _td @@person.githubUsername
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}"
              _a ' (*)', href: "ppmc/#{@@ppmc.id}#crosscheck" if @@person.notSubbed and @@ppmc.analysePrivateSubs
            }
        _td @@person.githubUsername
        _td @@person.name
      end

      _td data_ids: @@person.id do
        if @@person.selected
          if @@auth.ipmc and not @@person.icommit
            _button.btn.btn_primary 'Add as an incubator committer',
              data_action: 'add icommit',
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} as a committer " +
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
