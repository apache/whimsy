# send summary email to committers

validate_board_file(@agenda)

# fetch minutes
@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = File.join(AGENDA_WORK, @minutes.sub('.txt', '.yml'))

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

# ensure headers have proper CRLF
header, body = @text.split(/\r?\n\r?\n/, 2)
header.gsub! /\r?\n/, "\r\n"

# send mail
ASF::Mail.configure
mail = Mail.new("#{header}\r\n\r\n#{body}")
mail.deliver!

# update todos
minutes[:todos] ||= {}
minutes[:todos][:summary_sent] ||= true
File.write minutes_file, YAML.dump(minutes)

# return response
{mail: mail.to_s, minutes: minutes}
