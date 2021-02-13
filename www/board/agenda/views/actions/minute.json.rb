#
# Add secretarial minutes to a given agenda item
#
require 'active_support/core_ext/time'

validate_board_file(@agenda)

@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = File.join(AGENDA_WORK, @minutes.sub('.txt', '.yml'))

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

if @action == 'timestamp'

  timestamp = ASF::Board::TIMEZONE.now

  @text = timestamp.strftime('%-H:%M')

  if @title == 'Call to order'
    minutes['started']  = timestamp.gmtime.to_f * 1000
  elsif @title == 'Adjournment'
    minutes['complete'] = timestamp.gmtime.to_f * 1000
  end

elsif @action == 'attendance'

  # lazily initialize attendance information
  attendance = minutes['attendance'] ||= {}
  agenda = Agenda.parse @agenda, :quick
  people = agenda.find {|item| item['title'] == 'Roll Call'}['people']
  people.each {|id, person| attendance[person[:name]] ||= {present: false}}

  # update attendance records for attendee
  attendance[@name] = {
    id: @id,
    present: @present,
    notes: (@notes and not @notes.empty?) ? " - #@notes" : nil,
    member: ASF::Person.find(@id).asf_member?,
    sortName: @name.split(' ').rotate(-1).join(' ')
  }

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
else
  @text = @text.reflow(0, 78)
end

if @text and not @text.empty?
  minutes[@title] = @text
else
  minutes.delete @title
  minutes.delete 'started'  if @title == 'Call to order'
  minutes.delete 'complete' if @title == 'Adjournment'
end

if @reject
  minutes[:rejected] ||= []
  minutes[:rejected] << @title unless minutes[:rejected].include? @title
elsif minutes[:rejected]
  minutes[:rejected].delete @title
end

File.write minutes_file, YAML.dump(minutes)

minutes
