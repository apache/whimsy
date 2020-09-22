#
# This is the client model for draft Minutes.
#

class Minutes
  Vue.util.defineReactive @@list, {}

  # (re)-load minutes
  def self.load(list)
    @@list = list || {}
    Vue.set @@list, 'attendance', {} unless @@list.attendance
  end

  # list of actions created during the meeting
  def self.actions
    actions = []

    @@list.each_pair do |title, minutes|
      minutes += "\n\n"
      pattern = RegExp.new('^(?:@|AI\s+)(\w+):?\s+([\s\S]*?)(\n\n|$)', 'g')
      match = pattern.exec(minutes)
      while match
        actions << {owner: match[1], text: match[2], item: Agenda.find(title)}
        match = pattern.exec(minutes)
      end
    end

    return actions
  end

  # fetch minutes for a given agenda item, by title
  def self.get(title)
    return @@list[title]
  end

  def self.attendees
    @@list.attendance
  end

  def self.rejected
    @@list.rejected
  end

  # return a list of actual or expected attendee names
  def self.attendee_names
    names = []

    attendance = Object.keys(@@list.attendance)

    if attendance.empty?
      rollcall = Minutes.get('Roll Call') || Agenda.find('Roll-Call').text
      pattern = Regexp.new('\n ( [a-z]*[A-Z][a-zA-Z]*\.?)+', 'g')
      while (match=pattern.exec(rollcall)) do
        name = match[0].sub(/^\s+/, '').split(' ').first
        names << name unless names.include? name
      end
    else
      attendance.each do |name|
        next unless @@list.attendance[name].present
        name = name.split(' ').first
        names << name unless names.include? name
      end
    end

    names.sort()
  end

  # return a list of directors present
  def self.directors_present
    rollcall = Minutes.get('Roll Call') || Agenda.find('Roll-Call').text
    rollcall[/Directors.*Present:\n\n((.*\n)*?)\n/,1].sub(/\n$/, '')
  end

  # determine if the meeting has started
  def self.started
    @@list.started
  end

  # determine if the meeting is over
  def self.complete
    @@list.complete
  end

  # determine if the draft is ready
  def self.ready_to_post_draft
    self.complete and
      not Server.drafts.include?  Agenda.file.sub('_agenda_', '_minutes_')
  end

  # determine if the draft is ready
  def self.draft_posted
    Server.drafts.include?  Agenda.file.sub('_agenda_', '_minutes_')
  end

  # determine if committers summary has been sent
  def self.summary_sent
    @@list.todos and @@list.todos.summary_sent
  end
end

Events.subscribe :minutes do |message|
  Minutes.load(message.value) if message.agenda == Agenda.file
end
