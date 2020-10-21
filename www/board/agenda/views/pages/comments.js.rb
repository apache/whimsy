#
# A page showing all comments present across all agenda items
# Conditionally hide comments previously marked as seen.
#

class Comments < Vue
  def self.buttons()
    buttons = []

    if
      MarkSeen.undo or
      Agenda.index.any? {|item| not item.unseen_comments.empty?}
    then
      buttons << {button: MarkSeen}
    end

    if Pending.seen and not Pending.seen.keys().empty?
      buttons << {button: ShowSeen}
    end

    return buttons
  end

  def initialize
    @showseen = false
  end

  def mounted
    EventBus.on :toggleseen, self.toggleseen
  end

  def beforeDestroy()
    EventBus.off :toggleseen, self.toggleseen
  end

  def toggleseen()
    @showseen = ! @showseen
  end

  def render
    found = false

    Agenda.index.each do |item|
      next if item.comments.empty?

      visible = (@showseen ? item.comments : item.unseen_comments)

      unless visible.empty?
        found = true

        _section do
          _Link text: item.title, href: item.href, class: "h4 #{item.color}"

          visible.each do |comment|
            _pre.comment comment
          end
        end
      end
    end

    unless found
      _p do
        if Pending.seen.keys().empty?
          _em 'No comments found'
        else
          _em 'No new comments found'
        end
      end
    end
  end
end
