#
# A page showing all queued approvals and comments, as well as items
# that are ready for review.
#

class Shepherd < React
  def render
    shepherd = @@item.shepherd.downcase()

    actions = Agenda.find('Action-Items')
    if actions.actions.any? {|action| action.owner == @@item.shepherd}
      _h2 'Action Items'
      _ActionItems item: actions, filter: {owner: @@item.shepherd}
      _h2 'Committee Reports'
    end

    # list agenda items associated with this shepherd
    first = true
    Agenda.index.each do |item|
      if item.shepherd and item.shepherd.downcase().start_with? shepherd
        _h3 class: item.color do
          _Link text: item.title, href: "shepherd/queue/#{item.href}",
            class: ('default' if first)
          first = false
        end

        if item.missing
          posted = Posted.get(item.title)
          unless posted.empty?
            _h4 'Posted reports'
            _ul posted do |post|
              _li do
                _a post.subject, href: post.link
              end
            end
          end
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
