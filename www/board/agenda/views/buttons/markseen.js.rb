#
# A button that mark all comments as 'seen', with an undo option
#
class MarkSeen < Vue
  def initialize
    @disabled = false
    @label = 'mark seen'
    MarkSeen.undo = nil
  end

  def render
    _button.btn.btn_primary @label, onClick: self.click, disabled: @disabled
  end

  def click(event)
    @disabled = true

    if MarkSeen.undo
      seen = MarkSeen.undo
    else
      seen = {}
      Agenda.index.each do |item|
        if item.comments and not item.comments.empty?
          seen[item.attach] = item.comments
        end
      end
    end

    post 'markseen', seen: seen, agenda: Agenda.file do |pending|
      @disabled = false

      if MarkSeen.undo
        MarkSeen.undo = nil
        @label = 'mark seen'
      else
        MarkSeen.undo = Pending.seen
        @label = 'undo mark'
      end

      Pending.load pending
    end
  end
end
