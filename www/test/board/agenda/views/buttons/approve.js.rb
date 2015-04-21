#
# Approve/Unapprove/Reject a report
#
class Approve < React
  def initialize
    @disabled = false
    @request = 'approve'
  end

  # render a single button
  def render
    _button.btn.btn_primary @request, onClick: self.click, disabled: @disabled
  end

  # set request and button text on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # set request (and button text) depending on whether or not the
  # shift key is down and whether or not this items was previously approved
  def componentWillReceiveProps()
    if Keyboard.shift
      @request = 'reject'
    elsif Pending.approved.include? @@item.attach
      @request = 'unapprove'
    else
      @request = 'approve'
    end
  end

  # when button is clicked, send request
  def click(event)
    data = {
      agenda: Agenda.file,
      attach: @@item.attach,
      request: @request
    }

    @disabled = true
    post 'approve', data do |pending|
      @disabled = false
      Pending.load pending
    end
  end
end
