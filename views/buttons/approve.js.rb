#
# Approve/Unapprove/Flag/Unflag a report
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
  # not this items was previously approved
  def componentWillReceiveProps()
    if Keyboard.shift
      if Pending.flagged.include? @@item.attach
        @request = 'unflag'
      elsif Pending.unflagged.include? @@item.attach
        @request = 'flag'
      elsif @@item.flagged_by and @@item.flagged_by.include? Server.initials
        @request = 'unflag'
      else
        @request = 'flag'
      end
    else
      if Pending.approved.include? @@item.attach
        @request = 'unapprove'
      elsif Pending.unapproved.include? @@item.attach
        @request = 'approve'
      elsif @@item.approved and @@item.approved.include? Server.initials
        @request = 'unapprove'
      else
        @request = 'approve'
      end
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
