#
# A page showing all flagged reports
#

class Flagged < React
  def render
    first = true

    Agenda.index.each do |item|
      if item.flagged_by or Pending.flagged.include? item.attach
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false
        end

        _AdditionalInfo item: item
      end
    end

    _em.comment 'None' if first
  end
end
