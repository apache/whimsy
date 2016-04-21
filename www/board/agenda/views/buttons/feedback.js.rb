#
# SendFeedback
#
class SendFeedback < React
  def render
    _button.btn.btn_warning 'send feedback to PMCs', onClick: self.click,
    title: 'prepare feedback for PMCs from board meeting'
  end

  def click(event)
    window.location.href = 'feedback'
  end
end
