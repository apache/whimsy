# find the latest agenda
agenda_file = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort.last.untaint
agenda = Agenda.parse File.basename(agenda_file), :quick

agenda

