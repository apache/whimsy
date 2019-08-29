#
# Indicate intention to attend / regrets for meeting
#
class Attend < Vue
  def initialize
    @disabled = false
  end

  def render
    _button.btn.btn_primary (attending ? 'regrets' : 'attend'),
      onClick: self.click, disabled: @disabled
  end

  # match person by either userid or name
  def attending
    return false unless @@item.people
    person = @@item.people[User.id]
    if person
      return person.attending
    else
      @@item.people.each_pair do |id, person|
        return person.attending if person.name == User.username
      end
      return false
    end
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      action: (attending ? 'regrets' : 'attend'),
      name: User.username,
      userid: User.id
    }

    @disabled = true
    post 'attend', data do |response|
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
