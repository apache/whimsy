#
# Approve/Unapprove a report
#
class Approve < React
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary (@approved ? 'unapprove' : 'approve'),
      onClick: self.click, disabled: @disabled
  end

  def componentWillMount()
    self.componentWillReceiveProps()
  end

  def componentWillReceiveProps()
    @approved = Pending.approved.include? @@item.attach
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      attach: @@item.attach,
      request: (@approved ? 'unapprove' : 'approve')
    }

    @disabled = true
    post 'approve', data do |pending|
      @disabled = false
      Pending.load pending
    end
  end
end
