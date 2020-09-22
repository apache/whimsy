#
# Secretary Roll Call update form

class RollCall < Vue
  def initialize
    RollCall.lockFocus = false
    @guest = ''
  end

  def render
    _section.flexbox do
      _section.rollcall! do
        _h3 'Directors'
        _ul people do |person|
          _Attendee person: person if person.role == :director
        end

        _h3 'Executive Officers'
        _ul people do |person|
          _Attendee person: person if person.role == :officer
        end

        _h3 'Guests'
        _ul do
          people.each do |person|
            _Attendee person: person if person.role == :guest
          end

          # walk-on guest support
          _li do
            _input.walkon value: @guest, disabled: @disabled,
              onFocus:-> {RollCall.lockFocus = true},
              onBlur:-> {RollCall.lockFocus = false}
          end

          if @guest.length >= 3
            guest = @guest.downcase().split(' ')

            found = false
            Server.committers.each do |person|
              if
                guest.all? {|part|
                  person.id.include? part or
                  person.name.downcase().include? part
                } and
                not people.any? {|registered| registered.id == person.id}
              then
                _Attendee person: person, walkon: true
                found = true
              end
            end

            # non committer
            _Attendee person: {name: @guest}, walkon: true if not found
          end
        end
      end

      # draft minutes
      _section do
        minutes = Minutes.get(@@item.title)
        if minutes
          _h3 'Minutes'
          _pre.comment minutes
        end
      end
    end
  end

  # collect a sorted list of people
  def people
    list = []

    # start with those listed in the agenda
    @@item.people.each_pair do |id, person|
      person.id = id
      list << person
    end

    # add remaining attendees
    attendees = Minutes.attendees
    if attendees
      attendees.each_pair do |name, attendee|
        if not list.any? {|person| person.name == name}
          person = attendee
          person.name = name
          person.role = :guest
          list << person
        end
      end
    end

    # sort list
    list.sort do |person1, person2|
      return person1.sortName > person2.sortName ? 1 : -1
    end
  end

  # clear guest
  def clear_guest()
    @guest = ''
  end

  # client side initialization on first rendering
  def mounted()
    if Server.committers
      @disabled = false
    else
      @disabled = true
      retrieve 'committers', :json do |committers|
        Server.committers = committers || []
        @disabled = false
      end
    end

    # export clear method
    RollCall.clear_guest = self.clear_guest
  end

  # scroll walkon input field towards the center of the screen
  def updated()
    if RollCall.lockFocus and @guest.length >= 3
      walkon = document.getElementsByClassName("walkon")[0]
      offset = walkon.offsetTop + walkon.offsetHeight/2 - window.innerHeight/2
      jQuery('html, body').animate({scrollTop: offset}, :slow)
    end
  end
end

#
# An individual attendee (Director, Executive Officer, or Guest)
#
class Attendee < Vue
  def initialize
    # last posted value for notes for this attendee
    @base = ''
  end

  def created
    @base = status.notes
  end

  # create a version of notes without the leading dash
  def notes
    status.notes ? status.notes.sub(' - ', '') : ''
  end

  def notes=(value)
    if value
      status.notes = " - #{value}"
    else
      status.notes = nil
    end
  end

  # perform initialization on first rendering
  def status
    return @saved_status if Header.clock_counter > 0
    @saved_status = Minutes.attendees[@@person.name] || {}
  end

  # render a checkbox, a hypertexted link of the attendee's name to the
  # roster page for the committer, and notes in both editable and non-editable
  # forms.  CSS controls which version of the notes is actually displayed.
  def render
    _li onMouseOver: self.focus do
      _input type: :checkbox, checked: status.present, onClick: self.click

      roster = '/roster/committer/'
      if @@person.id
        _a @@person.name, href: "#{roster}#{@@person.id}",
          style: {fontWeight: (@@person.member ? 'bold' : 'normal')}
      else
        _a.hilite @@person.name, href: "#{roster}?q=#{@@person.name}"
      end

      unless @@walkon or status.present or @@person.role==:guest or @@person.attending
        _span "\u00A0(expected to be absent)" unless status.notes
      end

      unless @@walkon
        _label
        _input type: 'text', value: self.notes, onBlur: self.blur,
          disabled: @disabled
        _span status.notes
      end
    end
  end

  # when moving cursor over a list item, focus on the input field
  def focus(event)
    unless RollCall.lockFocus
      event.target.parentNode.querySelector('input[type=text]').focus()
    end
  end

  # when checkbox is clicked, post update
  def click(event)
    status.present = event.target.checked
    post_update()
  end

  # when leaving a list item, post update if value changed
  def blur()
    if @base != status.notes
      @base = status.notes
      post_update()
    end
  end

  # send updates to the server
  def post_update()
    data = {
      agenda: Agenda.file,
      action: 'attendance',
      name: @@person.name,
      id: @@person.id,
      present: status.present,
      notes: notes
    }

    @disabled = true
    Header.clock_counter += 1
    post 'minute', data do |minutes|
      Header.clock_counter -= 1
      Minutes.load minutes
      RollCall.clear_guest() if @@walkon
      @disabled = false
    end
  end
end
