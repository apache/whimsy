#
# IPC server based on Ruby's DRB.  Manages publish and subscribe queues as
# well as distributed hash.
#
# Key principles:
#   * Reserves a 9146 as a socket
#
#   * All IPC server operations are provided by a single class, and all server
#     operations are class methods that return primitive (round-trippable to
#     JSON) objects.  This provides the IPC_Server logic the ability to
#     consistently capture and recover from DRBConnErrors.
#
#   * No I/O or computational intensive processing is provided by the IPC
#     server.  
#

require 'drb'
require 'thread'

class IPC_Server
  SOCKET = 'druby://:9146'

  attr_accessor :object

  def initialize(object)
    IPC_Server.start_server
    @object = object
  end

  def method_missing(method, *args, &block)
    loop do
      begin
        return @object.send method, *args, &block
      rescue DRb::DRbConnError => e
        IPC_Server.start_server
        sleep 0.1
      end
    end
  end

  def self.start_server
    pid = fork do
      # run server code in a separate process
      ruby = File.join(
        RbConfig::CONFIG["bindir"],
        RbConfig::CONFIG["ruby_install_name"] + RbConfig::CONFIG["EXEEXT"]
      )

      exec(ruby, __FILE__.dup.untaint, '--server-only')
    end

    Process.detach pid

    at_exit {Process.kill 'INT', pid rescue nil}
  end

  ENV['RACK_ENV'] ||= 'development'
end

# launch server or client
if ENV['RACK_ENV'] == 'test'

  require_relative 'events'
  IPC = EventService

elsif ARGV[0] == '--server-only'

  if  __FILE__ == $0
    Signal.trap('INT') {sleep 1; exit}
    Signal.trap('TERM') {exit}
    Signal.trap('USR2') {exit}

    require_relative 'events'

    begin
      DRb.start_service(IPC_Server::SOCKET, EventService)
      DRb.thread.join
    rescue Errno::EADDRINUSE => e
      exit
    end
  end

else

  # IPC client
  IPC = IPC_Server.new(DRbObject.new(nil, IPC_Server::SOCKET))

end

# For demonstration / debugging purposes
if __FILE__ == $0
  require 'etc'
  user = ARGV.pop || Etc.getlogin

  queue = IPC.subscribe(user)

  at_exit do
    IPC.unsubscribe(queue)
  end

  Thread.new do
    loop do
      event = IPC.pop(queue)
      if event
        puts '>> ' + event.inspect
      else
        queue = IPC.subscribe(user)
      end
    end
  end

  loop do
    data = gets.strip
    exit if data.empty?
    IPC.post data
  end
end
