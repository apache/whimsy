#
# Show a committee
#

class Committee < React
  def render
    auth = (@@auth.id == @@committee.chair or @@auth.secretary)

    _h1 do
      _a @@committee.display_name, href: @@committee.site
      _span ' '
      _small "established #{@@committee.established}"
    end

    _p @@committee.description

    _h2 'PMC'
    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
          _th 'starting date'
        end
      end

      roster = @@committee.roster

      for id in roster
        person = roster[id]
        person.id = id

        _PMCMember auth: auth, person: person, chair: @@committee.chair
      end

      _PMCMemberAdd if auth
    end

    if @@committee.committers.keys().all? {|id| @@committee.roster[id]}
      _p 'All committers are members of the PMC'
    else
      _h2 'Committers'
      _table.table.table_hover do
        _thead do
          _tr do
            _th 'id'
            _th 'public name'
          end
        end

        committers = @@committee.committers

        for id in committers
          next if @@committee.roster[id]
          _PMCCommitter auth: auth, person: {id: id, name: committers[id]}
        end

        _PMCCommitterAdd if auth
      end
    end
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
        _td { _button.btn.btn_warning 'remove from PMC' }
      elsif @@person.id == @@chair
        _td.chair 'chair'
      else
        _td ''
      end
    end
  end

  def select
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Add a member to the PMC
#

class PMCMemberAdd < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      if @state == :open
        _td '+'
        _td { _input }
        _td colspan: 2 do
          _button.btn.btn_primary 'add as a committer and to the PMC'
          _button.btn.btn_success 'add to PMC only'
        end
      else
        _td '+', colspan: 4
      end
    end
  end

  def select
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Show a committer
#

class PMCCommitter < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      _td {_a @@person.id, href: "committer/#{@@person.id}"}
      _td @@person.name

      if @state == :open
        _td do
          _button.btn.btn_warning 'remove as committer'
          _button.btn.btn_primary 'add to PMC'
        end
      else
        _td ''
      end
    end
  end

  def select
    return unless @@auth
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end

#
# Add a committer
#

class PMCCommitterAdd < React
  def initialize
    @state = :closed
  end

  def render
    _tr onDoubleClick: self.select do
      if @state == :open
        _td '+'
        _td { _input }
        _td colspan: 2 do
          _button.btn.btn_success 'add as a committer only'
          _button.btn.btn_primary 'add as a committer and to the PMC'
        end
      else
        _td '+', colspan: 4
      end
    end
  end

  def select
    window.getSelection().removeAllRanges()
    @state = ( @state == :open ? :closed : :open )
  end
end
