#
# Secretary version of Adjournment section: shows todos
#

class Adjournment < Vue
  def initialize
    @add = []
    @remove = []
    @change = []
    @terminate = []
    @establish = []
    @feedback = []
    @minutes = {}
    @loading = true
    @fetched = false
  end

  # export self as shared state
  def created()
    if defined? global
      global.Todos = self
    else
      window.Todos = self
    end
  end

  # update state
  def set(values)
    values.each_pair do |attr, value|
      Todos[attr] = value
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

  def render
    _section.flexbox do
      _section do
        _pre.report @@item.text

        if not Todos.loading or Todos.fetched
          _h3 'Post Meeting actions'

          if
            Todos.add.empty? and Todos.remove.empty? and
            Todos.change.empty? and Todos.establish.empty?
          then
            if Todos.loading
              _em 'Loading...'
            else
              _p.comment 'complete'
            end
          end
        end

        unless
          Todos.add.empty? and Todos.change.empty? and Todos.establish.empty?
        then
          _PMCActions
        end

        unless Todos.remove.empty?
          _TodoRemove
        end

        unless Todos.feedback.empty?
          _FeedbackReminder
        end

        # display a list of completed actions
        completed = Todos.minutes.todos
        if
          completed and completed.keys().length > 0 and (
          (completed.added and not completed.added.empty?) or
          (completed.changed and not completed.changed.empty?) or
          (completed.removed and not completed.removed.empty?) or
          (completed.established and not completed.established.empty?) or
          (completed.feedback_sent and not completed.feedback_sent.empty?))
        then
          _h3 'Completed actions'

          if completed.added and not completed.added.empty?
            _p 'Added to PMC chairs'
            _ul completed.added do |id|
              _li {_a id, href: "../../../roster/committer/#{id}"}
            end
          end

          if completed.changed and not completed.changed.empty?
            _p 'Changed PMC chairs'
            _ul completed.changed do |pmc|
              _li {_a pmc, href: "../../../roster/committee/#{pmc}"}
            end
          end

          if completed.removed and not completed.removed.empty?
            _p 'Removed from PMC chairs'
            _ul completed.removed do |id|
              _li {_a id, href: "../../../roster/committer/#{id}"}
            end
          end

          if completed.established and not completed.established.empty?
            _p 'Established PMCs'
            _ul completed.established do |pmc|
              _li {_a pmc, href: "../../../roster/committee/#{pmc}"}
            end
          end

          if completed.terminated and not completed.terminated.empty?
            _p 'Terminated PMCs'
            _ul completed.terminated do |pmc|
              _li {_a pmc.downcase(),
                 href: "../../../roster/committee/#{pmc.downcase()}"}
            end
          end

          if completed.feedback_sent and not completed.feedback_sent.empty?
            _p 'Sent feedback'
            _ul completed.feedback_sent do |pmc|
              _li {_Link text: pmc, href: pmc.gsub(/\s+/, '-')}
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

  # fetch secretary todos once the minutes are complete
  def load()
    if Minutes.complete and not Todos.fetched
      Todos.loading = true
      Todos.fetched = true
      retrieve "secretary-todos/#{Agenda.title}", :json do |todos|
        Todos.set todos
        Todos.loading = false
      end
    end
  end

  def mounted()
    self.load() if Todos.loading
  end
end

class PMCActions < Vue
  def initialize
    @resolutions = []
  end

  def render

    _ul.checklist @resolutions do |item|
      _li do
        _input type: 'checkbox', checked: item.checked,
          onClick:-> { item.checked = !item.checked; self.refresh() }

        _Link text: item.title, href: Todos.link(item.title)

        if item.minutes
          _ ' - '
          _Link text: item.minutes, href: Todos.link(item.title)
        end
      end
    end

    _button.checklist.btn.btn_default 'Submit', disabled: @disabled,
      onClick: self.submit
  end

  # gather a list of resolutions
  def created()
    @resolutions = []

    Agenda.index.each do |item|

      %w(change establish terminate).each do |todo_type|
        Todos[todo_type].each do |todo|
          if todo.resolution == item.title
            minutes = Minutes.get(item.title)

            resolution = {
              action: todo_type,
              name: todo.name,
              display_name: item.title.sub(/^#{escapeRegExp(todo_type)} /i, '').
                sub(/ Chair$/i, ''),
              title: item.title,
              minutes: minutes,
              checked: (not minutes.include? 'tabled')
            }

            resolution.chair = todo.chair if todo.chair
            resolution.people = todo.people if todo.people

            @resolutions << resolution
          end
        end
      end
    end

    self.refresh()
  end

  def refresh()
    @disabled = @resolutions.all? {|item| not item.checked}
  end

  def submit()
    data = {
      change: [],
      establish: [],
      terminate: []
    }

    @resolutions.each do |resolution|
      data[resolution.action] << resolution if resolution.checked
    end

    data.change = nil if data.change.empty?
    data.establish = nil if data.establish.empty?
    data.terminate = nil if data.terminate.empty?

    @disabled = true
    post "secretary-todos/#{Agenda.title}", data do |todos|
      @disabled = false
      Todos.set todos
    end
  end
end

########################################################################
#                            Remove chairs                             #
########################################################################

class TodoRemove < Vue
  def initialize
    @checked = {}
    @disabled = false
  end

  # update check marks based on current Todo list
  def created()
    Todos.remove.each do |person|
      if @checked[person.id] == undefined
        if not person.resolution or Minutes.get(person.resolution) != 'tabled'
          @checked[person.id] = true
        end
      end
    end
  end

  def render
    people = Todos.remove

    _p 'Remove from pmc-chairs:'

    _ul.checklist people do |person|
      _li do
        _input type: 'checkbox', checked: @checked[person.id],
          onClick:-> {
            @checked[person.id] = !@checked[person.id]
          }

        _a person.id,
          href: "/roster/committer/#{person.id}"
        _ " (#{person.name})"
      end
    end

    _button.checklist.btn.btn_default 'Submit', onClick: self.submit,
      disabled: (@disabled or people.length == 0 or
        not people.any? {|person| @checked[person.id]})
  end

  def submit()
    @disabled = true

    remove = []
    @checked.each_pair do |id, checked|
      remove << id if checked
    end

    post "secretary-todos/#{Agenda.title}", remove: remove do |todos|
      @disabled = false
      Todos.set todos

      # uncheck people who were removed
      @checked.each_key do |id|
        unless Todos.remove.any? {|person| person.id == id}
          @checked[id] = false
        end
      end
    end
  end
end

########################################################################
#                      Reminder to draft feedback                      #
########################################################################

class FeedbackReminder < Vue
  def render
    _p 'Draft feedback:'

    _ul.list_group.row Todos.feedback do |pmc|
      _li.list_group_item.col_xs_6.col_sm_4.col_md_3.col_lg_2 do
        _Link text: pmc, href: pmc.gsub(/\s+/, '-')
     end
    end

    _button.checklist.btn.btn_default 'Submit',
      onClick:-> {Main.navigate 'feedback'}
  end
end
