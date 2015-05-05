class Chat
  @@log = []

  def self.log
    @@log
  end

  def self.add(entry)
    if @@log.empty? or @@log.last.timestamp < entry.timestamp
      @@log << entry
    else
      for i in 0...@@log.length
        if entry.timestamp <= @@log[i].timestamp
          if entry.timestamp!=@@log[i].timestamp or entry.text!=@@log[i].text
            @@log.splice(i, 0, entry)
          end
          break
        end
      end
    end
  end
end

Events.subscribe :chat do |message|
  if message.agenda == Agenda.file
    message.delete agenda
    Chat.add message
  end
end

Events.subscribe :arrive do |message|
  Server.online = message.present
  Chat.add type: :info, user: message.user, timestamp: message.timestamp,
    text: 'joined the chat'
end

Events.subscribe :depart do |message|
  Server.online = message.present
  Chat.add type: :info, user: message.user, timestamp: message.timestamp,
    text: 'left the chat'
end
