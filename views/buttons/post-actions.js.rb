#
# Indicate intention to attend / regrets for meeting
#
class PostActions < React
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
      action: (@attending ? 'regrets' : 'attend'),
      name: Server.username,
      userid: Server.userid
    }

    @disabled = true
    post 'post-actions', data do |response|
      @disabled = false
      Agenda.load response.agenda
    end
  end
end
