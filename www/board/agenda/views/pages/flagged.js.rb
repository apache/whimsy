#
# A page showing all flagged reports
#
# On the meeting day, also show reports that are missing or don't have enough
# preapprovals.

class Flagged < Vue
  def render
    first = true
    meeting_day = Minutes.started || Agenda.meeting_day

    if meeting_day
      _p do
        _ 'Currently showing '; _span.commented 'flagged'; _ ', '
        _span.missing 'missing'; _ ', and '; _span.ready 'unapproved'
        _ ' reports.'
      end
    else
      _p do
        _ 'Currently only showing '; _span.commented 'flagged'
        _ ' reports. Starting with the meeting day, this list will also include '
        _span.missing 'missing'; _ ', and '
        _span.ready 'unapproved'; _ ' reports too.'
      end
    end

    Agenda.index.each do |item|
      flagged = item.flagged_by || Pending.flagged.include?(item.attach)

      if not flagged and meeting_day and item.attach =~ /^(\d+|[A-Z]+)$/
        flagged = !item.skippable
      end

      if flagged
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/#{item.href}",
            class: ('default' if first)
          first = false

          _span.owner " [#{item.owner} / #{item.shepherd}]"

          if item.flagged_by
            flagged_by = item.flagged_by.to_s.split(/,\s*/).map {|initials|
              Server.directors[initials] || initials
            }.join(', ')

            _span.owner " flagged by: #{flagged_by}"
          end
        end

        _AdditionalInfo item: item, prefix: true
      end
    end

    _em.comment 'None' if first
  end
end
