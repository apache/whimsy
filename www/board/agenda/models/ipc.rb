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
  AGENDA_WORK = ARGV[1] unless defined? AGENDA_WORK
  DRB_SOCKET = 'drbunix://' + File.expand_path('drb.sock', AGENDA_WORK)
  HIJACK_SOCKET = File.expand_path('hijack.sock', AGENDA_WORK)

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

      exec(ruby, __FILE__.dup.untaint, '--server-only' , AGENDA_WORK)
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
    STDERR.puts 'forked'
begin
    # daemonize
    # Process.daemon

    # clean up any sockets left behind
    if File.exist? IPC_Server::HIJACK_SOCKET
      begin
        UNIXSocket.new(IPC_Server::HIJACK_SOCKET).close
      rescue Errno::ECONNREFUSED
        File.unlink IPC_Server::HIJACK_SOCKET
      end
    end

    # try not to leave any sockets behind
    at_exit do
      STDERR.puts 'exiting'
      begin
        File.unlink IPC_Server::HIJACK_SOCKET
        File.unlink DRB_SOCKET.split('//').last
      rescue
      end
    end

    # exit on signal
    Signal.trap('INT') {sleep 1; STDERR.puts 'bye'; exit}
    Signal.trap('TERM') {STDERR.puts 'bye'; exit}
    Signal.trap('USR2') {STDERR.puts 'bye'; exit}

    # event code
    require_relative 'events'

    begin
      # start IPC connection to EventService
      DRb.start_service(IPC_Server::DRB_SOCKET, EventService)

      # listen for hijacked sockets
      STDERR.puts 'starting...'
      listener = UNIXServer.new(IPC_Server::HIJACK_SOCKET)
      STDERR.puts 'listening...'

      loop do
        Thread.start(listener.accept) do |client|
        STDERR.puts 'got something...'
          # Receive message, socket, pass to EventService
          msg, sockaddr, rflags, *controls = client.recvmsg(scm_rights: true)
          ancdata = controls.find {|ancdata| ancdata.cmsg_is?(:SOCKET, :RIGHTS)}
          client.close
          STDERR.puts msg
          STDERR.puts ancdata
          begin
          EventService.hijack(msg, ancdata.unix_rights[0]) if ancdata
          rescue Exception => e
            STDERR.puts e
          end
        end
      end

      DRb.thread.join
    rescue Errno::EADDRINUSE => e
      exit
    end
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
end
  end

else

  # IPC client
  IPC = IPC_Server.new(DRbObject.new(nil, IPC_Server::DRB_SOCKET))

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
