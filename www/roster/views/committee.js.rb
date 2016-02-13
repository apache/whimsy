class Committee < React
  def render
    _h1 do
      _a @@committee.display_name, href: @@committee.site
      _span ' '
      _small "established #{@@committee.established}"
    end

    _p @@committee.description

    _h2 'PMC'
    _table do
      roster = @@committee.roster.sort

      for id in roster
        person = roster[id]

        _tr do
          _td {_a id, href: "committer/#{id}"}
          _td person.name
          _td person.date

          if id == @@committee.chair
            _td.chair 'chair'
          end
        end
      end
    end

    if @@committee.committers.keys().all? {|id| @@committee.roster[id]}
      _p 'All committers are members of the PMC'
    else
      _h2 'Committers'
      _table do
        committers = @@committee.committers.sort

        for id in committers
          next if @@committee.roster[id]
          person = committers[id]

          _tr do
            _td {_a id, href: "committer/#{id}"}
            _td person
          end
        end
      end
    end
  end
end
