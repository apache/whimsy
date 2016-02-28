#
# Show a committee
#

class Group < React
  def render
    group = @@group
    members = group.members.keys().sort_by {|id| group.members[id]}

    # header
    _h1 do
      _span group.id
      _span.note " (#{group.type})"
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
          _tr do
            _td {_a id, href: "committer/#{id}"}
            _td group.members[id]
          end
        end
      end
    end
  end
end
