#!/usr/bin/env ruby
##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

$:.unshift File.realpath(File.expand_path('../' * 5 + 'lib', __FILE__))
require 'websocket-client-simple'
require 'optparse'
require 'ostruct'
require 'etc'

require_relative './session'

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
options.user = Etc.getlogin
options.restart = false

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

  opts.on "--user USER", 'User to log in as' do |user|
    options.user = user
  end

  opts.on "--restart", 'restart WebSocket daemon process' do
    options.restart = true
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
  Dir["#{Session::WORKDIR}/*"].find do |file| 
    if File.read(file) == options.user
      if options.restart
        ws.send "session: #{File.basename(file)}\nrestart: true\n\n"
      else
        ws.send "session: #{File.basename(file)}\n\n"
      end
    end
  end
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
