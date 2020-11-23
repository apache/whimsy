require 'listen'
require 'thread'

class Events
  @@list = []

  def initialize
    @@list.push self

    @events = Queue.new

    @listener = Listen.to ARCHIVE do |modified, added, removed|
      (modified + added).each do |file|
         next unless file.end_with? '.yml'
         mbox = Mailbox.new(File.basename(file))
         @events.push({messages: mbox.client_headers})
      end
    end

    @listener.start

    @closed = false

    # As some TCP/IP implementations will close idle sockets after as little
    # as 30 seconds, sent out a heartbeat every 25 seconds.  Due to limitations
    # of some versions of Ruby (2.0, 2.1), this is lowered to every 5 seconds
    # in development mode to allow for quicker restarting after a trap/signal.
    Thread.new do
      loop do
        sleep(ENV['RACK_ENV'] == 'development' ? 5 : 25)
        break if @closed
        @events.push(:heartbeat)
      end

      @events.push(:exit)
      @listener.stop
    end
  end

  def pop
    @events.pop
  end

  def close
    @@list.delete self
    @events.clear
    @closed = true

    begin
      @events.push :exit
    rescue ThreadError
      # some versions of Ruby don't allow queue operations in traps
    end
  end

  def self.shutdown
    @@list.dup.each {|event| event.close}
  end
end

# puma uses SIGUSR2
restart_usr2 ||= trap 'SIGUSR2' do
  restart_usr2.call if restart_usr2.is_a? Proc
  Events.shutdown
end

# thin uses SIGHUP
restart_hup ||= trap 'SIGHUP' do
  restart_hup.call if restart_hup.is_a? Proc
  Events.shutdown
end
