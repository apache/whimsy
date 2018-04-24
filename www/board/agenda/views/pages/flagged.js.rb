#
# A page showing all flagged reports
#

class Flagged < Vue
  def render
    first = true

    Agenda.index.each do |item|
      flagged = item.flagged_by or Pending.flagged.include? item.attach

      if not flagged and Minutes.started and item.attach =~ /^(\d+|[A-Z]+)$/
        flagged = !item.skippable
      end

      if flagged
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"

          flagged_by = Server.directors[item.flagged_by] || item.flagged_by
          _span.owner " flagged by: #{flagged_by}" if flagged_by
        end

        _AdditionalInfo item: item, prefix: true
      end
    end

    _em.comment 'None' if first
  end
end
