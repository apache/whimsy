#
# Show a committee
#

class Group < React
  def initialize
    @state = :closed
    @pending = {}
  end

  def render
    group = @@group
    members = group.members.keys().sort_by {|id| group.members[id]}

    if group.type == 'LDAP auth group'
      auth = (members.include? @@auth.id or @@auth.secretary or @@auth.root)
    else
      auth = false 
    end

    # header
    _h1 do
      _span group.id
      _span.note " (#{group.type})"
    end

    # usage information for authenticated users (group members, etc.)
    if auth
      _div.alert.alert_success do
        _span 'Double click on a row to edit.'
        _span "  Double click on \u2795 to add."
      end
    end

    # list of members
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
        end
      end

      _tbody do
        members.each do |id|
          _GroupMember id: id, name: group.members[id], auth: auth, 
            pending: false
        end

        for id in @pending
          next if group.members[id]
          _GroupMember id: id, name: @pending[id], auth: auth, 
            pending: true
        end

        if auth
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

  # open search box
  def select()
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end

  # add a person to the displayed list of group members
  def add(person)
    @pending[person.id] = person.name
    @state = :closed
  end
end

#
# Show a member of the Group
#

class GroupMember < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      _td {_a @@id, href: "committer/#{@@id}"}
      _td @@name

      if @@pending
        _td do
          _button.btn.btn_success 'Add to Group',
            data_action: 'add group',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Add #{@@name}"
        end
      elsif @state == :open
        _td do
          _button.btn.btn_warning 'Remove from Group',
            data_action: 'remove group',
            data_target: '#confirm', data_toggle: 'modal',
            data_confirmation: "Remove #{@@name}"
        end
      else
        _td ''
      end
    end
  end

  # update props on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # automatically close row when id changes
  def componentWillReceiveProps(newprops)
    @state = :closed if newprops.id != @@id
  end

  # toggle display of buttons
  def select()
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
