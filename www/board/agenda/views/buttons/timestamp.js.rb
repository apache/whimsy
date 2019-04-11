#
# Timestamp start/stop of meeting
#
class Timestamp < Vue
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary 'timestamp',
      onClick: self.click, disabled: @disabled
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      title: @@item.title,
      action: 'timestamp'
    }

    @disabled = true
    post 'minute', data do |minutes|
      @disabled = false
      Minutes.load minutes
      Todos.load() if Minutes.complete
    end
  end
end
