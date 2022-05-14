require_relative '../asf'
require 'rack'
require 'etc'

module ASF
  # Rack support for HTTP Authorization, contains a number of classes that
  # can be <tt>use</tt>d within a <tt>config.ru</tt> of a Passenger application.
  module Auth
    # decode HTTP authorization, when present
    def self.decode(env)
      class << env; attr_accessor :user, :password; end

      auth = env['HTTP_AUTHORIZATION'] || ENV['HTTP_AUTHORIZATION']

      if auth.to_s.empty?
        env.user = env['REMOTE_USER'] || ENV['USER'] || Etc.getpwuid.name
      else
        require 'base64'
        env.user, env.password = Base64.
          decode64(auth[/^Basic ([A-Za-z0-9+\/=]+)$/, 1].to_s).split(':', 2)
      end

      env['REMOTE_USER'] ||= env.user

      ASF::Person.new(env.user)
    end

    # 'use' the following class in config.ru to limit access
    # to the application to ASF committers
    class Committers < Rack::Auth::Basic
      # Specify 'ASF Committers' as the HTTP auth Realm
      def initialize(app)
        super(app, "ASF Committers", &proc {})
      end

      # Returns <tt>unauthorized</tt> unless running in test mode or
      # the authenticated user is an ASF Committer
      def call(env)
        authorized = ( ENV['RACK_ENV'] == 'test' )

        # Must always call decode as it adds required accessors
        person = ASF::Auth.decode(env)

        authorized ||= person.asf_committer?

        if authorized
          @app.call(env)
        else
          unauthorized
        end
      end
    end

    # 'use' the following class in config.ru to limit access
    # to the application to ASF members and officers and the accounting group.
    class MembersAndOfficers < Rack::Auth::Basic
      # Specify 'ASF Members and Officers' as the HTTP auth Realm
      def initialize(app, &block)
        super(app, "ASF Members and Officers", &proc {})
        @block = block
      end

      # Returns <tt>unauthorized</tt> unless running in test mode or
      # the authenticated user is an ASF Member, a PMC Chair, or if a
      # block is specified on the <tt>new</tt> call, and that block
      # returns a <tt>true</tt> value.  Block is used by the board agenda
      # to allow invited guests to see the agenda.
      def call(env)
        authorized = ( ENV['RACK_ENV'] == 'test' )

        person = ASF::Auth.decode(env)

        authorized ||= person.asf_member?
        authorized ||= ASF.pmc_chairs.include? person
        authorized ||= @block.call(env) if @block

        if authorized
          @app.call(env)
        else
          unauthorized
        end
      end
    end
  end

  # 'use' the following class in config.ru to automatically run
  # Garbage Collection every 'n' requests, or 'm' minutes.
  #
  # This tries to run garbage collection "out of band" (i.e., between
  # requests), and when other requests are active (which can happen
  # with threaded servers like Puma).
  #
  # In addition to keeping memory usage bounded, this keeps the LDAP
  # cache from going stale.
  #
  class AutoGC
    @@background = nil

    # Define the frequency with which GC should be run (as in every 'n'
    # requests), and the maximum number of idle minutes between GC runs.
    # This class also will make use of PhusionPassenger's out of band GC,
    # if available.
    def initialize(app, frequency=100, minutes=15)
      @app = app
      @frequency = frequency
      @request_count = 0
      @queue = Queue.new
      @mutex = Mutex.new

      if defined?(PhusionPassenger)
        # https://github.com/suyccom/yousell/blob/master/config.ru
        # https://www.phusionpassenger.com/library/indepth/ruby/out_of_band_work.html
        if PhusionPassenger.respond_to?(:require_passenger_lib)
          PhusionPassenger.require_passenger_lib 'rack/out_of_band_gc'
        else
          # Phusion Passenger < 4.0.33
          require 'phusion_passenger/rack/out_of_band_gc'
        end

        @passenger = PhusionPassenger::Rack::OutOfBandGc.new(app, frequency)
      end

      Thread.kill(@@background) if @@background

      if minutes
        # divide minutes by frequency and use the result to determine the
        # time between simulated requests
        @@background = Thread.new do
          seconds = minutes * 60.0 / frequency
          loop do
            sleep seconds
            maybe_perform_gc
          end
        end
      end
    end

    # Rack middleware used to push an object onto the queue prior to the
    # request (this stops AutoGC from running during the request), and popping
    # it afterward the request completes.  Also will spin off a thread to
    # run GC after the reply completes (using rack.after_reply if available),
    # otherwise using a standard Thread.
    def call(env)
      @queue.push 1

      if @passenger
        @passenger.call(env)
      else
        # https://github.com/puma/puma/issues/450
        status, header, body = @app.call(env)

        if (ary = env['rack.after_reply']) # this is intended to be assignment, see #108
          ary << lambda {maybe_perform_gc}
        else
          Thread.new {sleep 0.1; maybe_perform_gc}
        end

        [status, header, body]
      end
    ensure
      @queue.pop
    end

    # Run GC when no requests are active and after every <tt>@frequency</tt>
    # events.
    def maybe_perform_gc
      @mutex.synchronize do
        @request_count += 1
        if @queue.empty? and @request_count >= @frequency
          @request_count = 0
          disabled = GC.enable
          GC.start
          GC.disable if disabled
        end
      end
    end
  end

  # Running deflate and etag together confuses caching:
  #
  # https://httpd.apache.org/docs/trunk/mod/mod_deflate.html#deflatealteretag
  #
  # http://scarff.id.au/blog/2009/apache-304-and-mod_deflate-revisited/
  #
  # workaround is to strip the suffix in Rack middleware
  class ETAG_Deflator_workaround
    # capture the app
    def initialize(app)
      @app = app
    end

    # strip <tt>-gzip</tt> from the <tt>If-None-Match</tt> HTTP header.
    def call(env)
      if env['HTTP_IF_NONE_MATCH']
        env['HTTP_IF_NONE_MATCH'] =
          env['HTTP_IF_NONE_MATCH'].sub(/-gzip"$/, '"')
      end

      return @app.call(env)
    end
  end

  # compute document root for the site.  Needed by Rack/Passenger applications
  # that wish to use support site wide assets (stylesheets, javascripts).
  class DocumentRoot
    # capture the application
    def initialize(app)
      @app = app
    end

    # compute the document root by stripping the <tt>PASSENGER_BASE_URI</tt> from
    # the the current working directory.
    def call(env)
      if ENV['PASSENGER_BASE_URI'] and not ENV['DOCUMENT_ROOT']
        base = Dir.pwd
        if base.end_with? ENV['PASSENGER_BASE_URI']
          base = base[0...-ENV['PASSENGER_BASE_URI'].length]
        end
        ENV['DOCUMENT_ROOT'] = base
      end

      return @app.call(env)
    end
  end

  # Apache httpd on the original whimsy-vm was behind a proxy that converts
  # https requests into http requests.  Update the environment variables to
  # match.  This middleware is likely now obsolete.
  class HTTPS_workarounds
    # capture the app
    def initialize(app)
      @app = app
    end

    # if <tt>HTTPS</tt> is set in the environment, rewrite the
    # <tt>SCRIPT_URI</tt> and <tt>SERVER_PORT</tt>; and strip
    # <tt>index.html</tt> from the <tt>PATH_INFO</tt> and <tt>SCRIPT_URI</tt>.
    def call(env)
      if env['HTTPS'] == 'on'
        env['SCRIPT_URI'].sub!(/^http:/, 'https:')
        env['SERVER_PORT'] = '443'

        # for reasons I don't understand, Passenger on whimsy doesn't
        # forward root directory requests directly, so as a workaround
        # these requests are rewritten and the following code maps
        # the requests back:
        if env['PATH_INFO'] == '/index.html'
          env['PATH_INFO'] = '/'
          env['SCRIPT_URI'] += '/'
        end
      end

      return @app.call(env)
    end
  end

end
