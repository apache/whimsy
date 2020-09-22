#
# A button that will do a 'svn update' of the agenda on the server
#
class Refresh < Vue
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary 'refresh', onClick: self.click,
      disabled: (@disabled or Server.offline)
  end

  def click(event)
    @disabled = true
    post 'refresh', agenda: Agenda.file do |response|
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
