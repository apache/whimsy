#
# chat message received from the client
#

@type ||= :chat

log = {type: @type, user: env.user, text: @text, timestamp: Time.now.to_f*1000}

log[:link] = @link if @link

if @text.start_with? '/me '
  log[:text].sub! /^\/me\s+/, '*** '
  log[:type] = :info
elsif @type == :chat
  chat = File.join(AGENDA_WORK, "#{@agenda.sub('.txt', '')}-chat.yml")
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
