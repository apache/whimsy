#
# Provide a thin interface to the Server.pending data structure, and
# implement the client side of offline processing.
#

class Pending
  Vue.util.defineReactive Server.pending, nil
  Vue.util.defineReactive Server.offline, false

  # fetch pending from server (needed for ServiceWorkers)
  def self.fetch()
    caches.open('board/agenda').then do |cache|
      fetched = false
      request = Request.new('pending.json', method: 'get',
        credentials: 'include', headers: {'Accept' => 'application/json'})

      # use data from last cache until a response is received
      cache.match(request).then do |response|
        if response and not fetched
          response.json().then do |json|
            Pending.load(json)
          end
        end
      end

      # update with the latest once available
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
    Pending.initialize_offline()
    Server.pending = value if value
    Main.refresh()
    return value
  end

  def self.count
    return 0 unless Server.pending and Agenda.file == Server.pending.agenda
    self.comments.keys().length +
      self.approved.length +
      self.unapproved.length +
      self.flagged.length +
      self.unflagged.length +
      self.status.keys().length
  end

  def self.comments
    return {} unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.comments || {}
  end

  def self.approved
    return [] unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.approved || []
  end

  def self.unapproved
    return [] unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.unapproved || []
  end

  def self.flagged
    return [] unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.flagged || []
  end

  def self.unflagged
    return [] unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.unflagged || []
  end

  def self.seen
    return {} unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.seen || {}
  end

  def self.status
    return [] unless Server.pending and Agenda.file == Server.pending.agenda
    Server.pending.status || []
  end

  # find a pending status update that matches a given action item
  def self.find_status(action)
    return nil unless Server.pending and Agenda.file == Server.pending.agenda
    match = nil

    Pending.status.each do |status|
      found = true
      action.each_pair do |name, value|
        found = false if name != 'status' and value != status[name]
      end
      match = status if found
    end

    return match
  end

  # determine if offline operatios are (or should be) supported
  def self.offline_enabled
    return false unless PageCache.enabled

    # disable offline in production for now
#   if location.hostname =~ /^whimsy.*\.apache\.org$/
#     return false unless location.hostname.include? '-test'
#   end

    return true
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
      db.createObjectStore('pending', keyPath: 'key')
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
        if request.result and request.result.agenda == Agenda.date
          block(request.result.value)
        else
          block({})
        end
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

  # change offline status
  def self.setOffline(status = true)
    Pending.initialize_offline()
    localStorage.setItem(Pending.offline_var, status.to_s)
    Server.offline = (status.to_s == 'true')
    Main.refresh()

    event = CustomEvent.new('offlineStatus', detail: Server.offline)
    window.dispatchEvent(event)
  end

  # synchronize offline status with other windows
  def self.initialize_offline()
    return if @@offline_initialized

    Pending.offline_var = "#{JSONStorage.prefix}-offline"

    if defined? localStorage
      if localStorage.getItem(Pending.offline_var) == 'true'
        Server.offline = true
      end

      # watch for changes
      window.addEventListener :storage do |event|
        if event.key == Pending.offline_var
          Server.offline = (event.newValue == 'true')

          event = CustomEvent.new('offlineStatus', detail: Server.offline)
          window.dispatchEvent(event)
        end
      end
    end

    if Server.offline
      # apply offline changes
      Pending.dbget do |pending|
        if pending.approve
          pending.approve.each_pair do |attach, request|
            Pending.update('approve', attach: attach, request: request)
          end
        end
      end
    end

    @@offline_initialized = true
  end

  # apply pending update request: if offline, capture request locally, otherwise
  # post it to the server.
  def self.update(request, data, &block)
    if Server.offline
      Pending.dbget do |pending|
        if request == 'comment'
          pending.comment ||= {}
          pending.comment[data.attach] = data.comment
          Server.pending.comments[data.attach] = data.comment
        elsif request == 'approve'
          # update list of offline requests
          if data.request.include? 'approve'
            pending.approve ||= {}
            pending.approve[data.attach] = data.request
          elsif data.request.include? 'flag'
            pending.flag ||= {}
            pending.flag[data.attach] = data.request
          end

          # apply request locally
          if data.request == 'approve'
            index = Server.pending.unapproved.indexOf(Server.pending.attach)
            Server.pending.unapproved.splice(index, 1) if index != -1
            unless Server.pending.approved.include? data.attach
              Server.pending.approved << data.attach
            end
          elsif data.request == 'unapprove'
            index = Server.pending.approved.indexOf(data.attach)
            Server.pending.approved.splice(index, 1) if index != -1
            unless Server.pending.unapproved.include? data.attach
              Server.pending.unapproved << data.attach
            end
          elsif data.request == 'flag'
            index = Server.pending.unflagged.indexOf(Server.pending.attach)
            Server.pending.unflagged.splice(index, 1) if index != -1
            unless Server.pending.flagged.include? data.attach
              Server.pending.flagged << data.attach
            end
          elsif data.request == 'unflag'
            index = Server.pending.flagged.indexOf(data.attach)
            Server.pending.flagged.splice(index, 1) if index != -1
            unless Server.pending.unflagged.include? data.attach
              Server.pending.unflagged << data.attach
            end
          end
        end

        # store offline requests
        Pending.dbput pending

        # inform caller, other tabs
        if block
          block(Server.pending)
          Events.broadcast type: 'pending', value: Server.pending
        end
      end
    else
      post request, data do |pending|
        block(pending)
        Pending.load(pending)
      end
    end
  end
end

Events.subscribe :pending do |message|
  Pending.load(message.value)
end
