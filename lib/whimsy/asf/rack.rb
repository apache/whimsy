require_relative '../asf.rb'
require 'rack'
require 'etc'
require 'thread'

module ASF
  module Auth
    DIRECTORS = {
      'rbowen'      => 'rb',
      'curcuru'     => 'sc',
      'bdelacretaz' => 'bd',
      'jim'         => 'jj',
      'mattmann'    => 'cm',
      'ke4qqq'      => 'dn',
      'brett'       => 'bp',
      'rubys'       => 'sr',
      'gstein'      => 'gs'
    }

    # decode HTTP authorization, when present
    def self.decode(env)
      class << env; attr_accessor :user, :password; end

      if env['HTTP_AUTHORIZATION'].to_s.empty?
        env.user = env['REMOTE_USER'] || ENV['USER'] || Etc.getpwuid.name
      else
        require 'base64'
        env.user, env.password = Base64.decode64(env['HTTP_AUTHORIZATION'][
          /^Basic ([A-Za-z0-9+\/=]+)$/,1].to_s).split(':',2)
      end

      env['REMOTE_USER'] ||= env.user

      ASF::Person.new(env.user)
    end

    # 'use' the following class in config.ru to limit access
    # to the application to ASF committers
    class Committers < Rack::Auth::Basic
      def initialize(app)
        super(app, "ASF Committers", &proc {})
      end

      def call(env)
        authorized = ( ENV['RACK_ENV'] == 'test' )

        authorized ||= ASF::Auth.decode(env).asf_committer?

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
      def initialize(app)
        super(app, "ASF Members and Officers", &proc {})
      end

      def call(env)
        authorized = ( ENV['RACK_ENV'] == 'test' )

        person = ASF::Auth.decode(env)

        authorized ||= DIRECTORS[env.user]
        authorized ||= person.asf_member?
        authorized ||= ASF.pmc_chairs.include? person

        if not authorized
          accounting = ASF::Authorization.new('pit').
            find {|group, list| group=='accounting'}
          authorized = (accounting and accounting.last.include? env.user)
        end

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

    def call(env)
      @queue.push 1

      if @passenger
        @passenger.call(env)
      else
        # https://github.com/puma/puma/issues/450
        status, header, body = @app.call(env)

        if ary = env['rack.after_reply']
          ary << lambda {maybe_perform_gc}
        else
          Thread.new {sleep 0.1; maybe_perform_gc}
        end

        [status, header, body]
      end
    ensure
      @queue.pop
    end

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

  # Apache httpd on whimsy-vm is behind a proxy that converts https
  # requests into http requests.  Update the environment variables to
  # match.
  class HTTPS_workarounds
    def initialize(app)
      @app = app
    end

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

      return  @app.call(env)
    end
  end

end
