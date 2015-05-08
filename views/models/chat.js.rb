class Chat
  @@log = []
  Chat.fetch_requested = false
  Chat.backlog_fetched = false

  # as it says: fetch backlog of chat messages from the server
  def self.fetch_backlog()
    return if Chat.fetch_requested

    fetch "chat/#{Agenda.file[/\d[\d_]+/]}", :json do |messages|
      messages.each {|message| Chat.add message}
      Chat.backlog_fetched = true
    end

    Chat.fetch_requested = true
  end

  # return the chat log
  def self.log
    @@log
  end

  # add an entry to the chat log
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

# subscriptions

Events.subscribe :chat do |message|
  if message.agenda == Agenda.file
    message.delete agenda
    Chat.add message
  end
end

Events.subscribe :info do |message|
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
