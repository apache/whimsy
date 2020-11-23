#!/usr/bin/env ruby

# Web socket client:
#  - securely connects and authenticates with the web socket
#  - outputs the messages received

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'websocket-eventmachine-client'
require 'optparse'
require 'ostruct'
require 'etc'
require 'net/http'
require 'json'

require_relative './session'

########################################################################
#                         Parse argument list                          #
########################################################################

options = OpenStruct.new
options.host = 'whimsy.local'
options.path = '/board/agenda/websocket/'
options.user = Etc.getlogin
options.restart = false
options.verify = true

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on "-h", "--host HOST", 'Host to connect to' do |host|
    options.host = host
  end

  opts.on "--port PORT", 'Port to connect to' do |port|
    options.port = port
  end

  opts.on "--path PORT", 'Path to connect to' do |path|
    options.path = path
  end

  opts.on "--secure", 'Use secure web sockets (wss)' do
    options.protocol = 'wss'
  end

  opts.on "--noverify", 'Bypass SSL certificate verification' do
    options.verify = false
  end

  opts.on "--user USER", 'User to log in as' do |user|
    options.user = user
  end

  opts.on "--restart", 'restart WebSocket daemon process' do
    options.restart = true
  end
end

opt_parser.parse!(ARGV)

options.protocol ||= (options.host.include?('local') ? 'ws' : 'wss')
options.port ||= 34234 if options.path=='/'
options.port ||= (options.protocol == 'ws' ? 80 : 443)

########################################################################
#                         Connect to WebSocket                         #
########################################################################

EM.run do
  url = "#{options.protocol}://#{options.host}:#{options.port}#{options.path}"
  puts "coonnecting to #{url}..."
  ws = WebSocket::EventMachine::Client.connect uri: url

  ws.onmessage do |msg, type|
    puts msg
  end

  ws.onopen do
    session = nil

    # see if there is a local session we can use
    if options.host.include? 'local'
      Dir["#{Session::WORKDIR}/*"].find do |file|
        session = File.basename(file) if File.read(file) == options.user
      end
    end

    # fetch remote session
    while not session
      require 'io/console'
      password = $stdin.getpass("password for #{options.user}: ")

      path = File.expand_path('../session.json', options.path)
      request = Net::HTTP::Get.new(path)
      request.basic_auth options.user, password

      http = Net::HTTP.new(options.host, options.port)
      if options.protocol == 'wss'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless options.verify
      end
      response = http.request(request)

      if response.is_a? Net::HTTPOK
        session = JSON.parse(response.body)['session']
      else
        p response
      end
    end

    if session
      if options.restart
        ws.send "session: #{session}\nrestart: true\n\n"
      else
        ws.send "session: #{session}\n\n"
      end
    end
  end

  ws.onclose do |code, reason|
    puts "closing: #{code}"
    exit 1
  end

  ws.onerror do |error|
    puts "error: #{error.inspect}"
  end
end
