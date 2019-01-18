#
# Simple web server that routes requests to views based on URLs.
#

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap'
require 'wunderbar/vue'
require 'ruby2js/es2017/strict'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'
#require 'erb'
#require 'sanitize'
require 'escape'

require 'whimsy/asf'

require_relative 'helpers'
require_relative 'models/mailbox'
require_relative 'models/safetemp'
require_relative 'models/events'
require_relative 'models/auth'
require_relative 'models/prefs'


# monkey patch mail gem to work around a regression introduced in 2.7.0:
# https://github.com/mikel/mail/pull/1168
module Mail
  class Message
    def raw_source=(value)
      @raw_source = ::Mail::Utilities.to_crlf(value)
    end
  end

  module Utilities
    def self.safe_for_line_ending_conversion?(string)
      if RUBY_VERSION >= '1.9'
        string.ascii_only? or 
          (string.encoding != Encoding::BINARY and string.valid_encoding?)
      else
        string.ascii_only?
      end
    end
  end
end

ASF::Mail.configure

set :show_exceptions, true

disable :logging # suppress log of requests to stderr/error.log

def get_pref # common setup
  @info = Auth.info({})
  @id = @info[:id]
  @prefs = Prefs.new()
  @domains = @prefs[@id] || []
end

def check_pref
  get_pref
  # TODO this forces user to choose at least one domain
  unless @domains && @domains.length > 0
    redirect to('/prefs')
  end
  pass
end

# Allow direct access to preferences
get '/prefs/?' do
  get_pref
  _html :prefs
end

# handle the update (easiest to use post from form button)
post '/actions/setprefs' do
  get_pref
  _html :"actions/setprefs"
end

# force user to use preferences if they have not yet done so
get   '*' do check_pref end
post  '*' do check_pref end
patch '*' do check_pref end

get '/' do
  # Ensure trailing slash is present
  redirect to('/') if env['REQUEST_URI'] == env['SCRIPT_NAME']
  _html :main
end

# initial list of messages
get '/messages' do # must agree with src in main.html

  @mbox = Mailbox.mboxname()
  @messages = Mailbox.new(@mbox, @domains).client_headers

  @cssmtime = File.mtime('public/secmail.css').to_i
  @appmtime = Wunderbar::Asset.convert(File.join(settings.views, 'app.js.rb')).mtime.to_i
  _html :messages # must agree with views/*.html.rb
end

# alias for root directory
get '/index.html' do
  call env.merge('PATH_INFO' => '/')
end

# list of messages for a month
get %r{/(#{MBOX_RE})/messages} do |mbox|

  @mbox = mbox
  @messages = Mailbox.new(@mbox, @domains).client_headers

  @cssmtime = File.mtime('public/secmail.css').to_i
  @appmtime = Wunderbar::Asset.convert(File.join(settings.views, 'app.js.rb')).mtime.to_i
  _html :messages # must agree with views/*.html.rb
end

# support for fetching next lot of messages
get %r{/(#{MBOX_RE})} do |mbox|
  _json Mailbox.new(mbox, @domains).client_headers
end

# retrieve a single message (same as body now)
get %r{/(#{MBOX_RE})/(#{HASH_RE})/} do |mbox, hash|
  @message = Mailbox.new(mbox).find(hash)
  return [404, {}, 'Message not found or is not accessible'] unless @message
  @attachments = @message.attachments
  @headers = @message.headers.dup
  @headers.delete :attachments
  @cssmtime = File.mtime('public/secmail.css').to_i
  _html :body #:message # must agree with views/*.html.rb
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end

# update a single message status (:Accept, :Reject, :Spam etc)
patch %r{/(#{MBOX_RE})/(#{HASH_RE})/} do |mbox, hash|

  updates = JSON.parse(request.env['rack.input'].read)

  success = Mailbox.patch!(mbox, hash, updates)

  return [404, {}, 'Message not found or is not accessible or could not be updated'] unless success

  [204, {}, '']
end

# message body for a single message
get %r{/(#{MBOX_RE})/(#{HASH_RE})/_body_} do |mbox, hash|
  @message = Mailbox.new(mbox).find(hash)
  return [404, {}, 'Message not found or is not accessible'] unless @message
  @attachments = @message.attachments
  @headers = @message.headers.dup
  @headers.delete :attachments
  @cssmtime = File.mtime('public/secmail.css').to_i
  _html :body # uses view/body.html.rb
end

# header data for a single message
get %r{/(#{MBOX_RE})/(#{HASH_RE})/_headers_} do |mbox, hash|
  @headers = Mailbox.new(mbox).headers(hash)
  return [404, {}, 'Message not found or is not accessible'] unless @headers
  _html :headers # uses view/headers.html.rb
end

# raw data for a single message
get %r{/(#{MBOX_RE})/(#{HASH_RE})/_raw_} do |mbox, hash|
  message = Mailbox.new(mbox).find(hash)
  return [404, {}, 'Message not found or is not accessible'] unless message
  [200, {'Content-Type' => 'text/plain'}, message.raw]
end

# original data for a single message (testing)
get %r{/(#{MBOX_RE})/(#{HASH_RE})/_orig_} do |mbox, hash|
  message = Mailbox.new(mbox).orig(hash)
  return [404, {}, 'Message not found or is not accessible'] unless message
  [200, {'Content-Type' => 'text/plain'}, message]
end

# intercede for potentially dangerous message attachments
get %r{/(#{MBOX_RE})/(#{HASH_RE})/_danger_/(.*?)} do |mbox, hash, name|
  message = Mailbox.new(mbox).find(hash)
  return [404, {}, 'Message not found or is not accessible'] unless message

  @part = message.find(URI.decode(name))
  return [404, {}, 'Attachment not found'] unless @part

  _html :danger
end

# a specific attachment for a message (e.g. CID)
# WARNING catches anything not handled above!
get %r{/(#{MBOX_RE})/(#{HASH_RE})/(.*?)} do |mbox, hash, name|
  message = Mailbox.new(mbox).find(hash)
  return [404, {}, 'Message not found or is not accessible'] unless message
  
  part = message.find(URI.decode(name))
  return [404, {}, 'Attachment not found'] unless part

  [200, {'Content-Type' => part.content_type}, part.body.to_s]
end

# event stream for server sent events (a.k.a EventSource)
get '/events', provides: 'text/event-stream' do
  events = Events.new

  stream :keep_open do |out|
    out.callback {events.close}

    loop do
      event = events.pop

      if Hash === event or Array === event
        out << "data: #{JSON.dump(event)}\n\n"
      elsif event == :heartbeat
        out << ":\n"
      elsif event == :exit
        out.close
        break
      else
        out << "data: #{event.inspect}\n\n"
      end
    end
  end
end

# catch everything else
get %r{/(.+)} do |req|
  [500, {}, "I don't understand the request: #{req}"]
end
