#
# Committers on the PPMC
#

class PPMCCommitters < React
  def render
    pending = [] 

    if @@ppmc.committers.all? {|id| @@ppmc.owners.include? id}
      _p 'All committers are members of the PPMC'
    else
      _h2.committers! 'Committers'
      _table.table.table_hover do
        _thead do
          _tr do
            _th if @@auth.ppmc
            _th 'id'
            _th 'public name'
            _th 'notes'
          end
        end

        _tbody do
          @committers.each do |person|
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

          if @@auth and @@auth.ppmc
            _tr onClick: self.select do
              _td((@state == :open ? '' : "\u2795"), colspan: 3)
            end
          end
        end
      end

      if @state == :open
        _div.search_box do
          _CommitterSearch add: self.add, multiple: true,
            exclude: @committers.map {|person| person.id unless person.issue}
        end
      end
    end
  end

  # update props on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # compute list of committers
  def componentWillReceiveProps()
    committers = []
    
    @@ppmc.committers.each do |id|
      person = @@ppmc.roster[id]
      person.id = id
      committers << person
    end

    @committers = committers.sort_by {|person| person.name}
  end

  # open search box
  def select()
    return unless @@auth and @@auth.ppmc
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # add a person to the displayed list of committers
  def add(person)
    person.status = 'pending'
    @committers << person
    @state = :closed
  end
end

#
# Show a committer
#

class PPMCCommitter < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do

      if @@auth.ppmc
        _td do
           _input type: 'checkbox', checked: @@person.selected || false,
             onChange: -> {self.toggleSelect(@@person)}, disabled: true
        end
      end

      if @@person.member
        _td { _b { _a @@person.id, href: "committer/#{@@person.id}"} }
        _td { _b @@person.name }
      else
        _td { _a @@person.id, href: "committer/#{@@person.id}" }
        _td @@person.name
      end

      if @state == :open
        _td data_ids: @@person.id do 
          if @@person.status == 'pending'
            _button.btn.btn_success 'Add as a committer and to the PPMC',
              data_action: 'add ppmc committer', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                 "#{@@ppmc.display_name} PPMC and grant committer access?"

            _button.btn.btn_primary 'Add as a committer only',
              data_action: 'add committer', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Grant #{@@person.name} committer access?"
          else
            if @@auth.ipmc and not @@person.icommit
              _button.btn.btn_primary 'Add as an incubator committer',
                data_action: 'add icommit',
                data_target: '#confirm', data_toggle: 'modal',
                data_confirmation: "Add #{@@person.name} as a commiter " +
                  "for the incubator PPMC?"
            end

            _button.btn.btn_warning 'Remove as Committer',
              data_action: 'remove committer', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Remove #{@@person.name} as a Committer?"

            _button.btn.btn_primary 'Add to PPMC',
              data_action: 'add ppmc', 
              data_target: '#confirm', data_toggle: 'modal',
              data_confirmation: "Add #{@@person.name} to the " +
                "#{@@ppmc.display_name} PPMC?"
          end
        end
      elsif not @@person.icommit
        _span.issue 'not listed as an incubator committer'
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
    @state = :closed if newprops.person.id != self.props.person.id
    @state = :open if @@person.status == 'pending'
  end

  # toggle display of buttons
  def select()
    return unless @@auth and @@auth.ppmc
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # toggle checkbox
  def toggleSelect(person)
    person.selected = !person.selected
    PPMC.refresh()
  end
end
