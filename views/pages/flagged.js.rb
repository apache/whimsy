#
# A page showing all flagged reports
#

class Flagged < React
  def render
    first = true

    Agenda.index.each do |item|
      if item.flagged_by
        _h3 class: item.color do
          _Link text: item.title, href: "flagged/queue/#{item.href}",
            class: ('default' if first)
          first = false
        end

        # show associated comments
        _h4 'Comments' unless item.comments.empty?
        item.comments.each do |comment|
          _pre.comment do
            _Text raw: comment, filters: [hotlink]
          end
        end

        # show associated action items
        if item.actions and not item.actions.empty?
          _h4 'Action Items'
          _ActionItems item: item, filter: {pmc: item.title}, form: :omit
        end
      end
    end
  end
end
