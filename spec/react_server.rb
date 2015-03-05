#
# This class spawns a io.js process to run a HTTP server which accepts
# POST requests containing React TestUtils scripts and responds with 
# HTML results.  It provides a Rack interface, enabling this server to
# be run with Capybara/RackTest.
#

require 'ruby2js'
require 'net/http'
require 'stringio'

class ReactServer
  @@pid = nil
  @@port = nil

  # start a new server
  def self.start
    return if @@pid

    # select an available port
    server = TCPServer.new('127.0.0.1', 0)
    @@port = server.addr[1]
    server.close

    # spawn a server process
    @@pid = spawn('iojs', '-e', 
      Ruby2JS.convert(@@server, {ivars: {:@port => @@port}}))

    # wait for server to start
    (0..10).each do |i|
      begin
        response = new.call('rack.input' => StringIO.new("response.end('hi')"))
        return if response.first == '200' and response.last == 'hi'
        STDERR.puts response
        raise RuntimeError('Invalid ReactServer response received')
      rescue Errno::ECONNREFUSED
        sleep i * 0.1
      end
    end
  end

  # rack compatible interface
  def call(env)
    http = Net::HTTP.new('localhost', @@port)
    request = Net::HTTP::Post.new('/', {})
    request.body = env['rack.input'].read
    response = http.request(request)
    [response.code, response.to_hash(), response.body]
  end

  # stop server
  def self.stop
    return unless @@pid
    http = Net::HTTP.new('localhost', @@port)
    request = Net::HTTP::Post.new('/', {})
    request.body = "response.end('bye'); process.exit(0)"
    response = http.request(request)
    Process.wait(@@pid)
    @@pid = nil
  end

  # the server itself
  @@server = proc do
    React = require('react')
    ReactAddons = require('react/addons')
    TestUtils = React.addons.TestUtils
    Simulate = TestUtils.Simulate

    jsdom = require("jsdom").jsdom
    global.document = jsdom('<html><body></body></html>')
    global.window = document.defaultView

    jQuery = require('jquery')

    http = require('http')
    server = http.createServer do |request, response|
      data = ''
      request.on('data') do |chunk| 
        data += chunk
      end

      request.on 'error' do |error|
        console.log "ReactServer error: #{error.message}"
      end

      request.on 'end' do
        response.writeHead(200, 'Content-Type' => 'text/plain')

        begin
          eval(data)
        rescue => error
          response.end(error.toString());
        end
      end
    end

    server.listen(@port)
  end
end
