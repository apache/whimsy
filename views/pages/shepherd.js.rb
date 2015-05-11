#
# A page showing all queued approvals and comments, as well as items
# that are ready for review.
#

class Shepherd < React
  def initialize
    @disabled = false
  end

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
        unless item.comments.empty?
          _h4 'Comments' 
          item.comments.each do |comment|
            _pre.comment do
              _Text raw: comment, filters: [hotlink]
            end
          end

          # flag action
          unless item.missing
            _button.shepherd.btn (item.flagged ? 'unflag' : 'flag'), 
              data_attach: item.attach,
              onClick: self.click, disabled: @disabled,
              class: (shepherd == Server.firstname ? 'btn-primary' : 'btn-link')
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

  def click(event)
    data = {
      agenda: Agenda.file,
      attach: event.target.getAttribute('data-attach'),
      request: event.target.textContent
    }

    @disabled = true
    post 'approve', data do |pending|
      @disabled = false
      Pending.load pending
    end
  end
end
