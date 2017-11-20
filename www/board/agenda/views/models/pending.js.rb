#
# Provide a thin (and quite possibly unnecessary) interface to the
# Server.pending data structure.
#

class Pending
  Vue.util.defineReactive Server.pending, nil

  # fetch pending from server (needed for ServiceWorkers)
  def self.fetch()
    caches.open('board/agenda').then do |cache|
      fetched = false
      request = Request.new('pending.json', method: 'get',
        credentials: 'include', headers: {'Accept' => 'application/json'})

      # use data from last cache until a response is received
      cache.match("../json/#{name}").then do |response|
        if response and not fetched
          response.json().then do |json| 
	    Pending.load(json)
          end
        end
      end

      # update with the lastest once available
      fetch(request).then do |response|
	if response.ok
          cache.put(request, response.clone())

	  response.json().then do |json|
            fetched = true
	    Pending.load(json)
	  end
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

  # offline storage using IndexDB
  def self.dbopen(&block)
    request = indexedDB.open("whimsy/board/agenda", 1)

    def request.onerror(event)
      console.log 'pending database not available'
    end

    def request.onsuccess(event)
      block(event.target.result)
    end

    def request.onupgradeneeded(event)
      db = event.target.result
      objectstore = db.createObjectStore('pending', keyPath: 'key')
    end
  end

  # fetch pending value.  Note: callback block will not be called if there
  # is no data, or if the data is for another month's agenda
  def self.dbget(&block)
    self.dbopen do |db|
      tx = db.transaction("pending", :readonly)
      store = tx.objectStore("pending")
      request = store.get('pending')

      def request.onerror(event)
	console.log 'no pending data'
      end

      def request.onsuccess(event)
	block(request.result.value) if request.result.date == Agenda.date
      end
    end
  end

  # update pending value.
  def self.dbput(value)
    self.dbopen do |db|
      tx = db.transaction("pending", :readwrite)
      store = tx.objectStore("pending")
      request = store.put(key: 'pending', agenda: Agenda.date, value: value)

      def request.onerror(event)
	console.log 'pending write failed'
      end
    end
  end
end

Events.subscribe :pending do |message|
  Pending.load(message.value)
end
