#
# Indicate intention to attend / regrets for meeting
#
class PostActions < Vue
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary 'post actions', onClick: self.click, 
      disabled: @disabled || SelectActions.list.empty?
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      message: 'Post Action Items',
      actions: SelectActions.list
    }

    @disabled = true
    post 'post-actions', data do |response|
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
