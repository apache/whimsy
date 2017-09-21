#
# Indicate intention to attend / regrets for meeting
#
class Attend < Vue
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary (@attending ? 'regrets' : 'attend'),
      onClick: self.click, disabled: @disabled
  end

  # match person by either userid or name
  def created()
    person = @@item.people[Server.userid]
    if person
      @attending = person.attending
    else
      @attending = false
      for id in @@item.people
        person = @@item.people[id]
        @attending = person.attending if person.name == Server.username
      end
    end
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      action: (@attending ? 'regrets' : 'attend'),
      name: Server.username,
      userid: Server.userid
    }

    @disabled = true
    post 'attend', data do |response|
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
