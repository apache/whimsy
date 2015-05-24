#
# Secretary Roll Call update form

class RollCall < React
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

      _section do
        minutes = Minutes.get(@@item.title)
        if minutes
          _h3 'Minutes'
          _pre.comment minutes
        end
      end
    end
  end

  # perform initialization on first rendering
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # collect a sorted list of people
  def componentWillReceiveProps()
    people = []

    for id in @@item.people
      person = @@item.people[id]
      person.id = id
      people << person
    end

    people.sort do |person1, person2| 
      return person1.sortName > person2.sortName ? 1 : -1
    end

    @people = people
  end
end

#
# An individual attendee (Director, Executive Officer, or Guest)
#
class Attendee < React
  def initialize
    # last posted value for notes for this attendee
    @base = ''
  end

  # perform initialization on first rendering
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # whenever person changes, reflect current status
  def componentWillReceiveProps()
    status = Minutes.attendees[@@person.name]
    if status
      @checked = status.present
      @notes = (status.notes ? status.notes.sub(' - ', '') : '')
    else
      @checked = ''
      @notes = ''
    end
  end

  # render a checkbox, a hypertexted link of the attendee's name to the
  # roster page for the committer, and notes in both editable and non-editable
  # forms.  CSS controls which version of the notes is actually displayed.
  def render
    _li onMouseOver: self.focus do
      _input type: :checkbox, checked: @checked, onChange: self.click,
        disabled: @disabled

      _a @@person.name, 
        style: {fontWeight: (@@person.member ? 'bold' : 'normal')},
        href: "https://whimsy.apache.org/roster/committer/#{@@person.id}"

      _label
      _input type: 'text', value: @notes, onBlur: self.blur, disabled: @disabled
      _span " - #@notes" if @notes
    end
  end

  # when moving cursor over a list item, focus on the input field
  def focus(event)
    event.target.parentNode.querySelector('input[type=text]').focus()
  end

  # initialize pending update status
  def componentDidMount()
    self.pending = false
  end

  # when checkbox is clicked, set pending update status
  def click(event)
    @checked = event.target.checked
    self.pending = true
  end

  # when leaving a list item, set pending update status if value changed
  def blur()
    if @base != @notes
      self.pending = true
      @base = @notes
    end
  end

  # after display is updated, send any pending updates to the server
  def componentDidUpdate()
    return unless self.pending

    data = {
      agenda: Agenda.file,
      action: 'attendance',
      name: @@person.name,
      present: @checked,
      notes: @notes
    }

    @disabled = true
    post 'minute', data do |minutes|
      Minutes.load minutes
      @disabled = false
    end

    self.pending = false
  end
end
