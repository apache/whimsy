#
# Post Action items
#
class PostActions < Vue
  def initialize
    @disabled = false
    @list = []
  end

  def render
    _button.btn.btn_primary 'post actions', onClick: self.click,
      disabled: @disabled || @list.empty?
  end

  def mounted()
    EventBus.on :potential_actions, self.potential_actions
  end

  def beforeDestroy()
    EventBus.off :potential_actions, self.potential_actions
  end

  def potential_actions(list)
    @list = list
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      message: 'Post Action Items',
      actions: @list
    }

    @disabled = true
    post 'post-actions', data do |response|
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
