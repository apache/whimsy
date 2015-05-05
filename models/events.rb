#
# A centralized subscription service for server side events
#  * Sends a heartbeat every 25 seconds
#  * Closes all sockets when restart is detected
#

class Events < Queue
  attr_accessor :user

  @@subscriptions = []
  @@restart = false

  # create a new subscription
  def self.subscribe(user)
    self.hook_restart
    present = Events.present
    events = Events.new(user)
    @@subscriptions << events
    if not present.include? user
      Events.post type: :arrive, user: user, present: Events.present,
        timestamp: Time.now.to_f*1000
    end
    events
  end

  # post an event to all subscribers
  def self.post(event)
    @@subscriptions.each do |subscriber| 
      if not event[:private] or event[:private] == subscriber.user
        subscriber << event
      end
    end
    event
  end

  # list of users present
  def self.present
    @@subscriptions.map(&:user).uniq.sort
  end

  # capture user information associated with this queue
  def initialize(user)
    @user = user
    super()
  end

  # remove a subscription
  def unsubscribe
    @@subscriptions.delete self
    present = Events.present
    if not present.include? @user
      Events.post type: :depart, user: @user, present: present,
        timestamp: Time.now.to_f*1000
    end
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
  # in development mode to allow for quicker restarting after a trap/signal.
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
