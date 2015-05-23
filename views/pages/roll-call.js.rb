class RollCall < React
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  def componentWillReceiveProps()
    people = []

    for id in @@item.people
      people << @@item.people[id]
    end

    people.sort do |person1, person2| 
      person1.sortName < person2.sortName ? 1 : -1
    end

    @people = people
  end

  def render
    _section.flexbox do
      _section.rollcall! do
        _h3 'Directors'
        _ul @people do |person|
          _Attendee person: person if person.role == :director
        end

        _h3 'Executive Officers'
        _ul @people do |person|
          _Attendee person: person if person.role == :officer
        end

        _h3 'Guests'
        _ul @people do |person|
          _Attendee person: person if person.role == :guest
        end
      end
    end
  end
end

class Attendee < React
  def render
    _li onMouseOver: self.focus do
      _input type: :checkbox

      _a @@person.name, 
        style: {fontWeight: (@@person.member ? 'bold' : 'normal')},
        href: "https://whimsy.apache.org/roster/committer/#{@@person.id}"

      _label
      _input type: 'text', value: @notes
      _span " - #@notes" if @notes
    end
  end

  def focus(event)
    event.target.querySelector('input[type=text]').focus()
  end
end
