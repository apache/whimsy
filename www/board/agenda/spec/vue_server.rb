#
# This class spawns a io.js process to run a HTTP server which accepts
# POST requests containing Vue/jsdom scripts and responds with
# HTML results.  It provides a Rack interface, enabling this server to
# be run with Capybara/RackTest.
#

require 'ruby2js'
require 'net/http'
require 'stringio'

require 'capybara/rspec'
require 'ruby2js/filter/vue'

class VueServer
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
    puts "Vue server is using: '#{nodejs}'"
    @@pid = spawn(nodejs, '-e',
      Ruby2JS.convert(@@server, {ivars: {:@port => @@port}}))

    # wait for server to start
    (0..10).each do |i|
      begin
        response = new.call('rack.input' => StringIO.new("response.end('hi')"))
        return if response.first == '200' and response.last == 'hi'
        STDERR.puts response
        raise RuntimeError('Invalid VueServer response received')
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
      _response = http.request(request)
    rescue Errno::ECONNREFUSED, EOFError
      nil
    ensure
      Process.wait(@@pid)
      @@pid = nil
    end
  end

  # the server itself
  @@server = proc do
    _cleanup = require("jsdom-global/register")
    delete global.XMLHttpRequest

    process.env.VUE_ENV = 'server'

    Vue = require('vue')
    Vue.config.productionTip = false

    # render a response, using server side rendering
    def Vue.renderResponse(component, response)
      renderer = require('vue-server-renderer').createRenderer()
      app = Vue.new(render: proc {|h| return h(component)})

      renderer.renderToString(app) do |err, html|
        if err
          response.end(err.toString() + "\n" + err.stack)
        else
          response.end(html)
        end
      end
    end

    # render a element, using client side rendering
    def Vue.renderElement(component)
      outer = document.createElement('div')
      inner = document.createElement('span')
      outer.appendChild(inner)
      Vue.new(el: inner, render: proc {|h| return h(component)})
      return outer.firstChild
    end

    # render an app, using client side rendering.  Convenience methods are
    # provided to querySelector, and to extract outerHTML.
    def Vue.renderApp(component)
      outer = document.createElement('div')
      inner = document.createElement('span')
      outer.appendChild(inner)
      app = Vue.new(el: inner, render: proc {|h| return h(component)})
      inner = outer.firstChild # appears not to be used, but it is

      def app.outerHTML
        return inner.outerHTML
      end

      def app.querySelector(selector)
        return outer.querySelector(selector)
      end

      return app
    end

    jQuery = require('jquery') # the variable jQuery is needed, even if it appears not

    http = require('http')
    server = http.createServer do |request, response|
      data = ''
      request.on('data') do |chunk|
        data += chunk
      end

      request.on 'error' do |error|
        console.error "VueServer error: #{error.message}"
      end

      request.on 'end' do
        response.writeHead(200, 'Content-Type' => 'text/plain')

        begin
          eval(data)
        rescue => error
          response.end(error.toString())
        end
      end
    end

    server.listen(@port)
  end
end

shared_context "vue_server", server: :vue do
  #
  # administrivia
  #
  before :all do
    VueServer.start
    Dir.chdir File.expand_path('../../views', __FILE__) do
      @_script = Ruby2JS.convert(File.read('app.js.rb'), file: 'app.js.rb')
    end
  end

  before :each do
    @_app, Capybara.app = Capybara.app, VueServer.new
  end

  def on_vue_server(&block)
    locals = {}
    instance_variables.each do |ivar|
      next if ivar.to_s.start_with? '@_'
      locals[ivar] = instance_variable_get(ivar)
    end

    page.driver.post('/', @_script + ';' +
      Ruby2JS.convert(block, vue: true, ivars: locals).to_s)
  end

  after :each do
    Capybara.app = @_app
  end

  at_exit do
    VueServer.stop
  end
end
