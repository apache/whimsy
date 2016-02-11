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

      roster = @@committee.roster

      for id in roster
        person = roster[id]

        _tr do
          _td {_a id, href: "committer/#{id}"}
          _td person.name
        end
      end
    end
  end
end
