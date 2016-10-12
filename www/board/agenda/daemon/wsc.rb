#!/usr/bin/env ruby
require 'bundler/setup'
require 'websocket-client-simple'
require 'optparse'
require 'ostruct'

# monkey patch for https://github.com/shokai/websocket-client-simple/issues/24
class WebSocket::Client::Simple::Client
  def sleep(*args)
    close
  end
end

########################################################################
#                         Parse argument list                          #
########################################################################

options = OpenStruct.new
options.host = 'localhost'
options.port = 34234
options.protocol = 'ws'

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on "-h", "--host HOST", 'Host to connect to' do |host|
    options.host = host
  end

  opts.on "-p", "--port PORT", 'Port to connect to' do |port|
    options.port = port
  end

  opts.on "--secure", 'Use secure web sockets (wss)' do
    options.protocol = 'wss'
  end
end

opt_parser.parse!(ARGV)

########################################################################
#                         Connect to WebSocket                         #
########################################################################

url ="#{options.protocol}://#{options.host}:#{options.port}"
ws = WebSocket::Client::Simple.connect url

ws.on :message do |msg|
  puts msg.data
end

ws.on :open do
  ws.send 'hello!!!'
end

ws.on :close do |e|
  puts "closing: #{e.inspect}"
  exit 1
end

ws.on :error do |e|
  puts "error: #{e.inspect}"
end

loop do
  ws.send STDIN.gets
end
