#
# Show PMC members
#

class PMCMembers < Vue
  def initialize
    @committee = {}
    @committers = []
  end

  def render
    _h2.pmc! 'PMC (' + roster.length + ')'
    _p 'Click on column name to sort'
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
          _PMCMember auth: @@auth, person: person, committee: @@committee
        end
      end
    end
    if @@committee.analysePrivateSubs
      _h4.crosscheck! 'Cross-check of private@ list subscriptions'
      _p {
        _ 'PMC entries above with (*) do not appear to be subscribed to the private list.'
        _br
        _ 'This could be because the person is subscribed with an address that is not in their LDAP record'
      }
      # separate out the known ASF members and extract any matching committer details
      unknownSubs = @@committee.unknownSubs
      asfMembers = @@committee.asfMembers
      unknownSecSubs = @@committee.unknownSecSubs
      # Any unknown subscribers?
      if unknownSubs.length > 0
        _p {
          # We don't use the short-hand name: value syntax here to work-round Eclipse Ruby editor parsing bug
          _span.glyphicon.glyphicon_lock aria_hidden: true, :class => 'text-primary', 'aria-label' => 'ASF Members and private@ moderators'
          _ 'The following subscribers to the private list do not match the known emails for any of the existing PMC (or ASF) members.'
          _br
          _ 'They could be PMC (or ASF) members whose emails are not listed in their LDAP record.'
          _br
          _ 'Or they could be ex-PMC members who are still subscribed.'
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
      # Any unknown security@ subscribers?
      if unknownSecSubs.length > 0
        _h2.crosschecksec! 'Check of security@ list subscriptions'
        _p {
          # We don't use the short-hand name: value syntax here to work-round Eclipse Ruby editor parsing bug
          _span.glyphicon.glyphicon_lock aria_hidden: true, :class => 'text-primary', 'aria-label' => 'ASF Members and private@ moderators'
          _ 'The following subscribers to the security@ list do not match the known emails for any of the existing PMC (or ASF) members.'
          _br
          _ 'They could be PMC (or ASF) members whose emails are not listed in their LDAP record.'
          _br
          _ 'Or they could be ex-PMC members who are still subscribed.'
          _br
          _ '(Note that digest subscriptions are not currently included)'
          _br
          _br
          _ul {
            unknownSecSubs.each do |sub|
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
    end
  end

  def mounted()
    jQuery('.table', $el).stupidtable()
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
      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}" }
              _a ' (*)', href: "committee/#{@@committee.id}#crosscheck" if @@person.notSubbed and @@committee.analysePrivateSubs
            }
        _td @@person.githubUsername
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}"
              _a ' (*)', href: "committee/#{@@committee.id}#crosscheck" if @@person.notSubbed and @@committee.analysePrivateSubs
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
                data_confirmation: "Remove #{@@person.name} as committer and " +
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
        _td.chair.clickable (@@committee.pmc_chair ? 'chair' : 'chair (not in pmc-chairs)'), onClick: self.select
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
    @@committee.refresh()
  end
end
