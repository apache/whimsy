#
# chat message received from the client
#

log = {type: :chat, user: env.user, text: @text, timestamp: Time.now.to_f*1000}

if @text.start_with? '/me '
  log[:text].sub! /^\/me\s+/, '*** '
  log[:type] = :info
else
  chat = "#{AGENDA_WORK}/#{@agenda.sub('.txt', '')}-chat.yml"
  File.write(chat, YAML.dump([])) if not File.exist? chat

  File.open(chat, 'r+') do |file|
    file.flock(File::LOCK_EX)
    data = YAML.load(file.read)
    file.rewind
    data << log
    file.write YAML.dump(data)
  end
end

Events.post log.merge(agenda: @agenda)
