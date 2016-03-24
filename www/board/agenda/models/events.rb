#
# A centralized subscription service for server side events
#  * Sends a heartbeat every 25 seconds
#  * Closes all sockets when restart is detected
#

require 'json'

class EventService
  attr_accessor :user
  attr_accessor :token
  attr_accessor :queue

  @@subscriptions = {}
  @@restart = false
  @@next_token = 1
  @@cache = Hash.new(mtime: 0)

  # key/value store (for agenda purposes)
  def self.[](file)
    @@cache[file]
  end

  def self.[]=(file, data)
    @@cache[file] = data
  end

  # create a new subscription
  def self.subscribe(user)
    self.hook_restart
    present = EventService.present
    subscriber = EventService.new(user)
    @@subscriptions[subscriber.token] = subscriber
    if not present.include? user
      EventService.post type: :arrive, user: user, 
        present: EventService.present, timestamp: Time.now.to_f*1000
    end
    subscriber.token
  end

  # post an event to all subscribers
  def self.post(event)
    return unless event

    @@subscriptions.each do |token, subscriber|
      if
        not Hash === event or not event[:private] or # broadcast
        event[:private] == subscriber.user           # narrowcast
      then
        subscriber.queue << event
      end
    end
    event
  end

  # list of users present
  def self.present
    @@subscriptions.map {|token, subscriber| subscriber.user}.uniq.sort
  end

  # capture user information associated with this queue
  def initialize(user)
    @user = user
    @token = @@next_token
    @queue = Queue.new
    @@next_token += 1
    super()
  end

  def self.pop(token)
    subscription = @@subscriptions[token]
    subscription.queue.pop if subscription
  end

  # remove a subscription
  def self.unsubscribe(token)
    event = @@subscriptions.delete token
    present = EventService.present
    if event and not present.include? event.user
      EventService.post type: :depart, user: event.user, present: present,
        timestamp: Time.now.to_f*1000
    end
  end

  # send events to a hijacked socket
  def self.hijack(user, socket)
    STDERR.puts 'hijacked'
    subscription = subscribe(user)
    loop do
      event = pop(subscription)
      STDERR.puts event
      if Hash === event or Array === event
        socket.write "data: #{JSON.dump(event)}\n\n"
      elsif event == :heartbeat
        socket.write ":\n"
      elsif event == :exit
        break
      elsif event == nil
        subscription = subscribe(env.user)
      else
        socket.write "data: #{event.inspect}\n\n"
      end
      socket.flush
    end
  ensure
    STDERR.puts 'done'
    unsubscribe(subscription)
    socket.close
  end

  # When restart signal is detected, close all open connections
  def self.hook_restart
    # puma uses SIGUSR2
    restart_usr2 ||= trap 'SIGUSR2' do
      restart_usr2.call if Proc === restart_usr2
      begin
        EventService.post(:exit)
      rescue ThreadError
        # some versions of Ruby don't allow queue operations in traps
        @restart = true
      end
    end

    # thin uses SIGHUP
    restart_hup ||= trap 'SIGHUP' do
      restart_hup.call if Proc === restart_hup
      begin
        EventService.post(:exit)
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
        EventService.post(:exit)
        @restart = false
      else
        EventService.post(:heartbeat)
      end
    end
  end
end
