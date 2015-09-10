#
# A page showing all flagged reports
#

class Missing < React
  def render
    first = true

    Agenda.index.each do |item|
      if item.missing
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"

          if item.flagged_by
            flagged_by = Server.directors[item.flagged_by] || item.flagged_by
            _span.owner " flagged by: #{flagged_by}"
          end
        end

        _AdditionalInfo item: item
      end
    end

    _em.comment 'None' if first
  end
end
