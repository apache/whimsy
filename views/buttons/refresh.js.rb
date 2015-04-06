#
# A button that will do a 'svn update' of the agenda on the server
#
class Refresh < React
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary 'refresh', onClick: self.click, disabled: @disabled
  end

  def click(event)
    @disabled = true
    post 'refresh', agenda: Agenda.file do |response|
      @disabled = false
      Agenda.load response.agenda
    end
  end
end
