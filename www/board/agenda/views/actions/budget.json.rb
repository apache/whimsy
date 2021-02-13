#
# Add budget to minutes
#

validate_board_file(@agenda)

@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = File.join(AGENDA_WORK, @minutes.sub('.txt', '.yml'))

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

minutes['budget'] = @budget

File.write minutes_file, YAML.dump(minutes)

@budget
