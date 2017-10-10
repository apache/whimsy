#
# A page showing all reports that were NOT accepted
#

class Rejected < Vue
  def render
    first = true

    Agenda.index.each do |item|
      if item.rejected
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"
        end

        _AdditionalInfo item: item, prefix: true
      end
    end

    _em.comment 'None' if first
  end
end
