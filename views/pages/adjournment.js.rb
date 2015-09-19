#
# Secretary version of Adjournment section: shows todos
#

class Adjournment < React
  def initialize
    @todos = {add: [], remove: [], establish: [], loading: true, fetched: false}
  end

  def render
    _section.flexbox do
      _section do
        _pre.report @@item.text

        if not @todos.loading or @todos.fetched
          _h3 'Post Meeting actions'

          if 
            @todos.add.empty? and @todos.remove.empty? and 
            @todos.establish.empty?
          then
            if @todos.loading
              _em 'Loading...'
            else
              _p 'none'
            end
          end
        end

        unless @todos.add.empty?
          _TodoActions people: @todos.add, action: 'add'
        end

        unless @todos.remove.empty?
          _TodoActions people: @todos.remove, action: 'remove'
        end

        unless @todos.establish.empty?
          _p do
            _a 'Establish pmcs:', 
              href: 'https://infra.apache.org/officers/tlpreq'
          end

          _ul @todos.establish do |podling|
            _li do
              _span podling.name

              resolution = Minutes.get(podling.resolution)
              if resolution
                _ ' - '
                _Link text: resolution, href: self.link(podling.resolution)
              end
            end
          end
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

  # find corresponding agenda item
  def link(title)
    link = nil
    Agenda.index.each do |item|
      link = item.href if item.title == title
    end
    return link
  end

  # check for minutes being completed on first load
  def componentDidMount()
    self.componentDidUpdate()
  end

  # fetch secretary todos once the minutes are complete
  def componentDidUpdate()
    if Minutes.complete and @todos.loading and not @todos.fetched
      @todos.fetched = true
      fetch "secretary-todos/#{Agenda.title}", :json do |todos|
        @todos = todos
      end
    end
  end
end

class TodoActions < React
  def initialize
    @checked = {}
    @disabled = true
  end

  # check for minutes being completed on first load
  def componentDidMount()
    self.componentWillReceiveProps()
  end

  # fetch secretary todos once the minutes are complete
  def componentWillReceiveProps()
    # uncheck people who were removed
    for id in @checked
      unless @@people.any? {|person| person.id == id}
        @checked[id] = false
      end
    end

    # check people who were added
    @@people.each do |person|
      @checked[person.id] = true if @checked[person.id] == undefined
    end

    self.refresh()
  end

  def refresh()
    # disable button if nobody is checked
    disabled = true
    for id in @checked
      disabled = false if @checked[id]
    end
    @disabled = disabled

    self.forceUpdate()
  end

  def render
    if @@action == 'add'
      _p 'Add to pmc-chairs:'
    else
      _p 'Remove from pmc-chairs:'
    end

    _ul.checklist @@people do |person|
      _li do
        _input type: 'checkbox', checked: @checked[person.id],
          onChange:-> {
            @checked[person.id] = !@checked[person.id]
            self.refresh()
          }

        _a person.id,
          href: "https://whimsy.apache.org/roster/committer/#{person.id}"
        _ " (#{person.name})"

        if @action == 'add' and person.resolution
          resolution = Minutes.get(person.resolution)
          if resolution
            _ ' - '
            _Link text: resolution, href: self.link(person.resolution)
          end
        end
      end
    end

    if @@action == 'add'
      _button.checklist.btn.btn_default 'Email', disabled: @disabled,
        onClick: self.launch_email_client
    end

    _button.checklist.btn.btn_default 'Submit', disabled: @disabled,
      onClick: self.submit
  end

  def submit()
    @disabled = true

    data = {}
    data[@@action] = @checked

    post "secretary-todos/#{Agenda.title}", data do |todos|
      @disabled = false
      @todos = todos
    end
  end

  # launch email client, pre-filling the destination, subject, and body
  def launch_email_client()
    people = []
    @@people.each do |person|
      people << "#{person.name} <#{person.email}>" if @checked[person.id]
    end
    destination = "mailto:#{people.join(',')}?cc=board@apache.org"

    subject = "Congratulations on your new role at Apache"
    body = "Dear new PMC chairs,\n\nCongratulations on your new role at " +
    "Apache. I've changed your LDAP privileges to reflect your new " +
    "status.\n\nPlease read this and update the foundation records:\n" +
    "https://svn.apache.org/repos/private/foundation/officers/advice-for-new-pmc-chairs.txt" +
    "\n\nWarm regards,\n\n#{Server.username}"

    window.location = destination +
      "&subject=#{encodeURIComponent(subject)}" +
      "&body=#{encodeURIComponent(body)}"
  end
end
