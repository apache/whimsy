#
# common test setup
#

# prepend whimsy/lib to library search path
lib = File.expand_path('../' * 5 + 'lib', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib

ENV['RACK_ENV'] = 'test'
ENV['REMOTE_USER'] = 'test'
require 'capybara/rspec'
require "selenium-webdriver"
require_relative '../main'
Capybara.app = Sinatra::Application
Capybara.javascript_driver = :selenium_chrome_headless

require 'whimsy/asf/rack'

module MockServer
  # wunderbar environment
  def _
    self
  end

  # sinatra environment
  def env
    Struct.new(:user, :password).new('test', nil)
  end

  # capture wunderbar 'json' output methods
  def method_missing(method, *args, &block)
    if method =~ /^_(\w+)$/ and args.length == 1
      instance_variable_set "@#$1", args.first
    else
      super
    end
  end

  # run system commands, appending output to transcript.
  # intercept commits, adding the files to the cleanup list
  def system(*args)
    args.flatten!
    if args[1] == 'commit'
      @commits ||= {}
      @commits[File.basename args[2]] = File.read(args[2])
      `svn revert #{args[2]}`
      0
    else
      args.reject! {|arg| Array === arg}
      @transcript ||= ''
      @transcript += `#{Shellwords.join(args)}`
      $?.exitstatus
    end
  end
end

RSpec.configure do |config|
  config.include MockServer

  config.before(:each) do
    FileUtils.rm_rf Agenda::CACHE
    FileUtils.mkdir_p Agenda::CACHE
  end
end
