require 'websocket-client-simple'

# monkey patch for https://github.com/shokai/websocket-client-simple/issues/24
class WebSocket::Client::Simple::Client
  def sleep
    close
  end
end

ws = WebSocket::Client::Simple.connect 'ws://localhost:34234'

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
  ws.send STDIN.gets.strip
end
