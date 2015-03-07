#
# A page showing all comments present across all agenda items
#

class Comments < React
  def render
    found = false

    Agenda.index.each do |item|
      next if item.comments.empty?
      found = true

      _section do
        _h4 {_Link text: item.title, href: item.href}

        item.comments.each do |comment|
          _pre.comment comment
        end
      end
    end

    _p {_em 'No comments found'} unless found
  end
end
