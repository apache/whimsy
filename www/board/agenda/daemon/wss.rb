#!/usr/bin/env ruby
require 'bundler/setup'
require 'websocket-eventmachine-server'
require 'listen'
require 'ostruct'
require 'optparse'
require 'yaml'
require 'rbconfig'

require_relative './session'

users = Hash.new {|hash, key| hash[key] = []}
sessions = {}

########################################################################
#                         Parse argument list                          #
########################################################################

options = OpenStruct.new
options.host = '0.0.0.0'
options.port = 34234
options.privkey = Dir['/etc/letsencrypt/live/*/privkey.pem'].first
options.chain = Dir['/etc/letsencrypt/live/*/fullchain.pem'].first
options.kill = false
options.timeout = 900

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on "-h", "--host HOST", 'Host to listen on' do |host|
    options.host = host
  end

  opts.on "-p", "--port PORT", 'Port to listen on' do |port|
    options.port = port
  end

  opts.on "-k", "--key KEY", 'Private key' do |key|
    options.privkey = key
  end

  opts.on "-c", "--chain CHAIN", 'Certificate Chain' do |chain|
    options.chain = chain
  end

  opts.on "--kill [SIGNAL]", 'Kill existing process' do |signal|
    options.kill = signal || 'INT'
  end

  opts.on '-t', "--timeout [900]", 'inactivity timeout' do |timeout|
    options.timeout = timeout.to_i
  end
end

opt_parser.parse!(ARGV)

########################################################################
#                  Verify/enforce socket availability                  #
########################################################################

begin
  test_socket = TCPSocket.new('localhost', options.port)
  test_socket.close
  if options.kill
    `lsof -Fp -i :#{options.port} -sTCP:LISTEN`.scan(/^p(\d+)/).each do |(pid)|
      Process.kill 'INT', pid.to_i
    end
  else
    STDERR.puts 'socket in use'
    exit 1
  end
rescue Errno::ECONNREFUSED
end
exit 0 if options.kill

########################################################################
#                   Restart when source file changes                   #
########################################################################

listener = Listen.to(__dir__) do |modified, added, removed|
  puts 'restarting'
  exec RbConfig.ruby, File.expand_path(__FILE__), *ARGV
end
listener.start

########################################################################
#                  Close all open connection on exit                   #
########################################################################

at_exit do
  sessions.keys.each do |client|
    client.close
  end
end

########################################################################
#                        Start WebSocket server                        #
########################################################################

server_options = {host: options.host, port: options.port}

if options.privkey and options.chain
  server_options.merge! secure: true, 
    tls_options: {
      private_key_file: options.privkey,
      cert_chain_file: options.chain
    }
end

EM.run do
  WebSocket::EventMachine::Server.start(server_options) do |ws|
    ws.onclose do 
      id = sessions.delete(ws)
      users[id].delete ws if id
    end

    ws.onmessage do |msg|
      # extract headers
      headers = msg.slice!(/\A(\w+:\s*.*\r?\n)\s*(\n|\Z)/).to_s
      headers = YAML.safe_load(headers) || {} rescue {}

      if headers['session']
        session = Session[headers['session']]
        if session
          users[session[:id]] << ws
          sessions[ws] = session[:id]
          ws.send JSON.dump(session.merge type: 'login')
        end
      end

      # forward message
      unless msg.empty?
        if headers['private']
          # send only to a specific user
          clients = users[headers['private']] || []
        else
          # send to all users
          clients = sessions.keys
        end

        clients.each do |client|
          EM.defer(
            ->() {client.send msg},
            ->(response) {},
            ->(error) {client.close rescue nil}
          )
        end
      end
    end
  end
end
