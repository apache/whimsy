#
# Searchable PMC roster
#

class PMCRoster < React
  def render
    matches = []

    search = @@search.downcase().strip().split(/\s+/)

    for id in @@committee.roster do
      person = @@committee.roster[id]

      next unless search.all? {|term|
        id.include? term or person.name.downcase().include? term
      }

      person.id = id
      matches << person
    end

    matches = matches.sort_by {|person| person.name}

    _table.table.table_hover do
      _thead do
        _tr do
          _th 'id'
          _th 'public name'
        end
      end

      _tbody do
        matches.each do |person|
          _tr do
            if @@committee.asfmembers.include? person.id
              _td { _b { _a person.id, href: "committer/#{person.id}" } }
              _td { _b person.name }
            else
              _td { _a person.id, href: "committer/#{person.id}" }
              _td person.name
            end
            _td person.role
          end
        end
      end
    end

    if matches.length == 0
      _div.alert.alert_warning 'No matches'
    end
  end
end
