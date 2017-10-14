#
# Provide a thin (and quite possibly unnecessary) interface to the
# Server.pending data structure.
#

class Pending
  Vue.util.defineReactive Server.pending, nil

  # fetch pending from server (needed for ServiceWorkers)
  def self.fetch()
    fetch('pending.json', credentials: 'include').then do |response|
      if response.ok
        response.json().then do |json|
          Pending.load(json)
          Server.userid = json.userid if json and json.userid
        end
      end
    end
  end

  def self.load(value)
    Server.pending = value if value
    Main.refresh()
    return value
  end

  def self.count
    return 0 unless Server.pending
    self.comments.keys().length + 
      self.approved.length +
      self.unapproved.length +
      self.flagged.length +
      self.unflagged.length +
      self.status.keys().length
  end

  def self.comments
    (Server.pending && Server.pending.comments) || {}
  end

  def self.approved
    Server.pending.approved || []
  end

  def self.unapproved
    Server.pending.unapproved || []
  end

  def self.flagged
    Server.pending.flagged || []
  end

  def self.unflagged
    Server.pending.unflagged || []
  end

  def self.seen
    Server.pending.seen || {}
  end

  def self.initials
    Server.pending.initials || Server.initials
  end

  def self.status
    Server.pending.status || []
  end

  # find a pending status update that matches a given action item
  def self.find_status(action)
    match = nil

    Pending.status.each do |status|
      found = true
      for name in action
        found = false if name != 'status' and action[name] != status[name]
      end
      match = status if found
    end

    return match
  end
end

Events.subscribe :pending do |message|
  Pending.load(message.value)
end
