#
# This class spawns a io.js process to run a HTTP server which accepts
# POST requests containing React TestUtils scripts and responds with 
# HTML results.  It provides a Rack interface, enabling this server to
# be run with Capybara/RackTest.
#

require 'ruby2js'
require 'net/http'
require 'stringio'

require 'capybara/rspec'
require 'ruby2js/filter/react'

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
    nodejs = (`which nodejs`.empty? ? 'node' : 'nodejs')
    @@pid = spawn(nodejs, '-e', 
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

    begin
      http = Net::HTTP.new('localhost', @@port)
      request = Net::HTTP::Post.new('/', {})
      request.body = "response.end('bye'); process.exit(0)"
      response = http.request(request)
    rescue Errno::ECONNREFUSED
      nil
    ensure
      Process.wait(@@pid)
      @@pid = nil
    end
  end

  # the server itself
  @@server = proc do
    jsdom = require("jsdom").jsdom
    global.document = jsdom('<html><body></body></html>')
    global.window = document.defaultView
    global.navigator = global.window.navigator

    React = require('react')
    ReactDOM = require('react-dom')
    ReactDOMServer = require('react-dom/server');
    TestUtils = require('react-dom/test-utils')
    Simulate = TestUtils.Simulate

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

shared_context "react_server", server: :react do
  #
  # administrivia
  #
  before :all do
    ReactServer.start
    Dir.chdir File.expand_path('../../views', __FILE__) do
      @_script = Ruby2JS.convert(File.read('app.js.rb'), file: 'app.js.rb')
    end
  end

  before :each do
    @_app, Capybara.app = Capybara.app, ReactServer.new
  end

  def on_react_server(&block)
    locals = {}
    instance_variables.each do |ivar|
      next if ivar.to_s.start_with? '@_'
      locals[ivar] = instance_variable_get(ivar)
    end

    page.driver.post('/', @_script + ';' +
      Ruby2JS.convert(block, react: true, ivars: locals))
  end

  after :each do
    Capybara.app = @_app
  end

  at_exit do
    ReactServer.stop
  end
end
