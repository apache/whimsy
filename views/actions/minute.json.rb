#
# Add secretarial minutes to a given agenda item
#

@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = "#{AGENDA_WORK}/#{@minutes.sub('.txt', '.yml')}"
minutes_file.untaint if @minutes =~ /^board_minutes_\d+-\d+-\d+\.txt$/

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file)
else
  minutes = {}
end

if @action == 'timestamp'
  date = @agenda[/\d+_\d+_\d+/].gsub('_', '-')
  zone = Time.parse("#{date} PST").dst? ? '-07:00' : '-08:00'
  # workaround for broken tzinfo in ruby 1.9.3p0 on whimsy
  # month = @agenda[/\d+_(\d+)_\d+/, 1].to_i
  # zone = ((2..9).include? month) ? '-07:00' : '-08:00'
  @text = Time.now.getlocal(zone).strftime('%-l:%M')
end

minutes[@title] = @text

File.write minutes_file, YAML.dump(minutes)

Events.post type: :minutes, agenda: @agenda, value: minutes

minutes
