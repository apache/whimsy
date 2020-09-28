#
# Motivation: browsers limit the number of open web socket connections to any
# one host to somewhere between 6 and 250, making it impractical to have one
# Web Socket per tab.
#
# The solution below uses localStorage to communicate between tabs, with
# the majority of logic involved with the "election" of a master.  This
# enables a single open connection to service all tabs open by a browser.
#
# Alternatives include:
#
# * Replacing localStorage with Service Workers.  This would be much cleaner,
#   unfortunately Service Workers aren't widely deployed yet.  Sadly, the
#   state isn't much better for Shared Web Workers.
#
###
#
# Class variables:
# * prefix:    application prefix for localStorage variables (which are
#              shared across the domain).
# * timestamp: unique identifier for each window/tab
# * master:    identifier of the current master
# * ondeck:    identifier of the next in line to assume the role of master
#

class Events
  @@subscriptions = {}
  @@socket = nil

  def self.subscribe event, &block
    @@subscriptions[event] ||= []
    @@subscriptions[event] << block
  end

  def self.monitor()
    @@prefix = JSONStorage.prefix

    # pick something unique to identify this tab/window
    @@timestamp = Date.new().getTime() + Math.random()
    self.log "Events id: #{@@timestamp}"

    # determine the current master (if any)
    @@master = localStorage.getItem("#{@@prefix}-master")
    self.log "Events.master: #{@@master}"

    # register as a potential candidate for master
    localStorage.setItem("#{@@prefix}-ondeck", @@ondeck = @@timestamp)

    # relinquish roles on exit
    window.addEventListener :unload do |event|
      localStorage.removeItem("#{@@prefix}-master") if @@master == @@timestamp
      localStorage.removeItem("#{@@prefix}-ondeck") if @@ondeck == @@timestamp
    end

    # watch for changes
    window.addEventListener :storage do |event|
      # update tracking variables
      if event.key == "#{@@prefix}-master"
        @@master = event.newValue
        self.log "Events.master: #{@@master}"
        self.negotiate()
      elsif event.key == "#{@@prefix}-ondeck"
        @@ondeck = event.newValue
        self.log "Events.ondeck: #{@@ondeck}"
        self.negotiate()
      elsif event.key == "#{@@prefix}-event"
        self.dispatch event.newValue
      end
    end

    # dead man's switch: remove master when timestamp isn't updated
    if
      @@master and
      @@timestamp - localStorage.getItem("#{@@prefix}-timestamp") > 30_000
    then
      self.log 'Events: Removing previous master'
      @@master = localStorage.removeItem("#{@@prefix}-master")
    end

    # negotiate for the role of master
    self.negotiate()
  end

  # negotiate changes in masters
  def self.negotiate()
    if @@master == nil and @@ondeck == @@timestamp
      self.log 'Events: Assuming the role of master'

      localStorage.setItem("#{@@prefix}-timestamp", Date.new().getTime())
      localStorage.setItem("#{@@prefix}-master", @@master = @@timestamp)
      @@ondeck = localStorage.removeItem("#{@@prefix}-ondeck")

      if Server.session
        self.master()
      else
        options = {credentials: 'include'}
        request = Request.new("../session.json", options)
        fetch(request).then do |response|
          response.json().then do |json|
            Server.session = json.session
            self.master()
          end
        end
      end

    elsif
      @@ondeck == nil and @@master != @@timestamp and
      not localStorage.getItem("#{@@prefix}-ondeck")
    then
      localStorage.setItem("#{@@prefix}-ondeck", @@ondeck = @@timestamp)
    end
  end

  # master logic
  def self.master()
    self.connectToServer(false)

    # proof of life; maintain connection to the server
    setInterval 25_000 do
      localStorage.setItem("#{@@prefix}-timestamp", Date.new().getTime())

      if not Server.offline
        self.connectToServer(true)
      elsif @@socket
        @@socket.close()
      end
    end

    window.addEventListener :offlineStatus do |event|
      if event.detail == true
        @@socket.close() if @@socket
      else
        self.connectToServer(true)
      end
    end

    # close connection on exit
    window.addEventListener :unload do |event|
      @@socket.close() if @@socket
    end
  end

  # establish a connection to the server
  def self.connectToServer(check_for_updates)
    return if @@socket

    @@socket = WebSocket.new(Server.websocket)

    def @@socket.onopen(event)
      @@socket.send "session: #{Server.session}\n\n"
      self.log 'WebSocket connection established'

      if check_for_updates
        # see if the agenda or reporter data changed
        fetch('digest.json', credentials: 'include').then do |response|
          if response.ok
            response.json().then do |json|
              Events.broadcast json.agenda.merge(type: :agenda)
              Events.broadcast json.reporter.merge(type: :reporter)
            end
          end
        end
      end
    end

    def @@socket.onmessage(event)
      localStorage.setItem("#{@@prefix}-event", event.data)
      self.dispatch event.data
    end

    def @@socket.onerror(event)
      self.log 'WebSocket connection failed' if @@socket
      @@socket = nil
    end

    def @@socket.onclose(event)
      self.log 'WebSocket connection closed' if @@socket
      @@socket = nil
    end

  rescue => e
    self.log e
  end

  # set message to all processes
  def self.broadcast(event)
    begin
      event = event.inspect
      localStorage.setItem("#{@@prefix}-event", event)
      self.dispatch event
    rescue => e
      console.log(e)
      console.log(event)
    end
  end

  # dispatch logic (common to all tabs)
  def self.dispatch(data)
    message = JSON.parse(data)
    self.log message

    if message.type == :unauthorized
      options = {credentials: 'include'}
      request = Request.new("../session.json", options)
      fetch(request).then do |response|
        response.json().then do |json|
          self.log json
          Server.session = json.session
        end
      end
    elsif @@subscriptions[message.type]
      @@subscriptions[message.type].each {|sub| sub(message)}
    end

    Main.refresh()
  end

  # log messages (unless running tests)
  def self.log(message)
    return if !navigator.userAgent or navigator.userAgent.include? 'PhantomJS'
    console.log message
  end

  # make the computed prefix available
  def self.prefix
    return @@prefix if @@prefix

    # determine localStorage variable prefix based on url up to the date
    base = document.getElementsByTagName("base")[0].href
    origin = location.origin
    if not origin # compatibility: http://s.apache.org/X2L
      origin = window.location.protocol + "//" + window.location.hostname +
        (window.location.port ? ':' + window.location.port : '')
    end

    @@prefix = base[origin.length..-1].sub(/\/\d{4}-\d\d-\d\d\/.*/, '').
      gsub(/^\W+|\W+$/, '').gsub(/\W+/, '_') || location.port
  end
end
