#
# chat message received from the client
#

log = {user: env.user, text: @text, timestamp: Time.now.to_f*1000}

chat = "#{AGENDA_WORK}/#{@agenda.sub('.txt', '')}-chat.yml"
File.write(chat, YAML.dump([])) if not File.exist? chat

File.open(chat, 'r+') do |file|
  file.flock(File::LOCK_EX)
  data = YAML.load(file.read)
  file.rewind
  data << log
  file.write YAML.dump(data)
end

Events.post log.merge(type: :chat, agenda: @agenda)

log
