#
# A centralized subscription service for server side events
#  * Sends a heartbeat every 25 seconds
#  * Closes all sockets when restart is detected
#

class Events < Queue
  @@subscriptions = []

  @@restart = false

  # create a new subscription
  def self.subscribe
    self.hook_restart
    events = Events.new
    @@subscriptions << events
    events
  end

  # post an event to all subscribers
  def self.post(event)
    @@subscriptions.each {|subscriber| subscriber << event}
    event
  end

  # remove a subscription
  def unsubscribe
    @@subscriptions.delete self
  end

  # When restart signal is detected, close all open connections
  def self.hook_restart
    # puma uses SIGUSR2
    restart_usr2 ||= trap 'SIGUSR2' do
      restart_usr2.call if Proc === restart_usr2
      begin
        Events.post(:exit)
      rescue ThreadError
        # some versions of Ruby don't allow queue operations in traps
        @restart = true
      end
    end

    # thin uses SIGHUP
    restart_hup ||= trap 'SIGHUP' do
      restart_hup.call if Proc === restart_hup
      begin
        Events.post(:exit)
      rescue ThreadError
        # some versions of Ruby don't allow queue operations in traps
        @restart = true
      end
    end
  end

  # As some TCP/IP implementations will close idle sockets after as little
  # as 30 seconds, sent out a heartbeat every 25 seconds.  Due to limitations
  # of some versions of Ruby (2.0, 2.1), this is lowered to every 5 seconds
  # in development mode.
  Thread.new do
    loop do
      sleep(ENV['RACK_ENV'] == 'development' ? 5 : 25)

      if @restart
        Events.post(:exit)
        @restart = false
      else
        Events.post(:heartbeat)
      end
    end
  end
end
