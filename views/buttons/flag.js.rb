
# Flag/Unflag a report
#
class Flag < React
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

  # set request (and button text) to flip pending flagged status if set,
  # or current flagged status.
  def componentWillReceiveProps()
    if Pending.flagged and Pending.flagged.include? @@item.attach
      @request = 'unflag'
    elsif Pending.unflagged and Pending.unflagged.include? @@item.attach
      @request = 'flag'
    elsif @@item.flagged_by and @@item.flagged_by.include? Server.initials
      @request = 'unflag'
    else
      @request = 'flag'
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
    post 'flag', data do |pending|
      @disabled = false
      Pending.load pending
    end
  end
end
