#
# Motivation: browsers limit the number of open HTTP connections to any
# one host to somewhere between 4-10.  "Long polling" keeps an HTTP
# connection open making it impractical to have one EventSource per tab.
#
# The solution below uses localStorage to communicate between tabs, with
# the majority of logic involved with the "election" of a master.  This
# enables a single open connection to service all tabs open by a browser.
#
# Alternatives include: 
#
# * Replacing Server Side Events with Web Sockets which will require more open
#   connections (and therefore server load) as well as require special proxy
#   configuration (mod_proxy_wstunnel) and server coding (faye-websocket or
#   equivalent).
#
# * Replacing localStorage with Service Workers.  This would be much cleaner,
#   unfortunately Service Workers aren't widely deployed yet.  Sadly, the
#   state isn't much better for Shared Web Workers.
#
# Notable downside to Server Side Events is lack of native support by IE.
# This is readily addressed by a polyfill.
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

  def self.monitor()
    # determine localStorage variable prefix based on url up to the date
    base = document.getElementsByTagName("base")[0].href
    origin = location.origin
    @@prefix = base[origin.length..-1].sub(/\/\d{4}-\d\d-\d\d\/.*/, '').
      gsub(/^\W+|\W+$/, '').gsub(/\W+/, '_') || location.port

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

      self.master()

    elsif 
      @@ondeck == nil and @@master != @@timestamp and
      not localStorage.getItem("#{@@prefix}-ondeck") 
    then
      localStorage.setItem("#{@@prefix}-ondeck", @@ondeck = @@timestamp)
    end
  end

  # master logic
  def self.master()
    events = EventSource.new('/events')

    # dispatch events received to all windows
    events.addEventListener :message do |event|
      localStorage.setItem("#{@@prefix}-event", event.data)
      self.dispatch event.data
    end

    # proof of life
    setTimeout 25_000 do
      localStorage.setItem("#{@@prefix}-timestamp", Date.new().getTime())
    end

    # close connection on exit
    window.addEventListener :unload do |event|
      events.close()
    end
  end

  # dispatch logic (common to all tabs)
  def self.dispatch(data)
    # self.log data
    message = JSON.parse(data)

    if message.type == :chat
      Server.backchannel << message
    end

    Main.refresh()
  end

  # log messages (unless running tests)
  def self.log(message)
    return if !navigator.userAgent or navigator.userAgent.include? 'PhantomJS'
    console.log message
  end
end
