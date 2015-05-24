#
# Add secretarial minutes to a given agenda item
#

@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = "#{AGENDA_WORK}/#{@minutes.sub('.txt', '.yml')}"
minutes_file.untaint if @minutes =~ /^board_minutes_\d+-\d+-\d+\.txt$/

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

if @action == 'timestamp'

  # date = @agenda[/\d+_\d+_\d+/].gsub('_', '-')
  # zone = Time.parse("#{date} PST").dst? ? '-07:00' : '-08:00'
  # workaround for broken tzinfo on whimsy
  month = @agenda[/\d+_(\d+)_\d+/, 1].to_i
  zone = ((2..9).include? month) ? '-07:00' : '-08:00'
  @text = Time.now.getlocal(zone).strftime('%-l:%M')

elsif @action == 'attendance'

  # lazily initialize attendance information
  attendance = minutes['attendance'] ||= {}
  agenda = Agenda.parse @agenda, :quick
  people = agenda.find {|item| item['title'] == 'Roll Call'}['people']
  people.each {|id, person| attendance[person[:name]] ||= {present: false}}

  # update attendance records for attendee
  @notes = " - #@notes" if @notes and not @notes.empty?
  attendance[@name] = {present: @present, notes: @notes}

  # build minutes for roll call
  @text = "Directors Present:\n\n"
  people.each do |id, person|
    next unless person[:role] == :director
    name = person[:name]
    next unless attendance[name][:present]
    @text += "  #{name}#{attendance[name][:notes]}\n"
  end

  @text += "\nDirectors Absent:\n\n"
  first = true
  people.each do |id, person|
    next unless person[:role] == :director
    name = person[:name]
    next if attendance[name][:present]
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end
  @text += "  none\n" if first

  first = true
  people.each do |id, person|
    next unless person[:role] == :officer
    name = person[:name]
    next unless attendance[name][:present]
    @text += "\nExecutive Officers Present:\n\n" if first
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end

  @text += "\nExecutive Officers Absent:\n\n"
  first = true
  people.each do |id, person|
    next unless person[:role] == :officer
    name = person[:name]
    next if attendance[name][:present]
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end
  @text += "  none\n" if first

  first = true
  attendance.to_a.sort.each do |name, records|
    next unless records[:present]
    person = people.find {|id, person| person[:name] == name}
    next if person and not person.last[:role] == :guest
    @text += "\nGuests:\n\n" if first
    @text += "  #{name}#{attendance[name][:notes]}\n"
    first = false
  end

  @title = 'Roll Call'
end

minutes[@title] = @text

File.write minutes_file, YAML.dump(minutes)

Events.post type: :minutes, agenda: @agenda, value: minutes

minutes
