#
# common test setup
#

# prepend whimsy/lib to library search path
lib = File.expand_path('../' * 5 + 'lib', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib

ENV['RACK_ENV'] = 'test'
ENV['REMOTE_USER'] = 'test'
require 'capybara/rspec'
require_relative '../main'
Capybara.app = Sinatra::Application
Capybara.javascript_driver = :poltergeist

require 'whimsy/asf/rack'

# only load poltergeist driver for JavaScript if phantomjs is available
if
  ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
    File.exist? File.join(path, 'phantomjs')
  end
then
  require 'capybara/poltergeist'
else
  puts STDERR, "phantomjs is not available in PATH, not loading poltergeist"
end

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
      @cleanup <<= args[2] if @cleanup
    else
      @transcript ||= ''
      @transcript += `#{Shellwords.join(args)}`
    end
    0
  end
end

RSpec.configure do |config|
  config.include MockServer
end
