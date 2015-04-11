#
# A page showing all queued approvals and comments, as well as items
# that are ready for review.
#

class Shepherd < React
  def render
    shepherd = @@item.shepherd.downcase()

    # list agenda items associated with this shepherd
    Agenda.index.each do |item|
      if item.shepherd and item.shepherd.downcase().start_with? shepherd
        _h3 class: item.color do
          _Link text: item.title, href: "shepherd/queue/#{item.href}"
        end

        item.comments.each do |comment|
          _pre.comment do
            _Text raw: comment, filters: [hotlink]
          end
        end

        if item.actions and not item.actions.empty?
          _h4 'Action Items'
          item.actions.each do |action|
            _pre.comment action
          end
        end
      end
    end
  end
end
