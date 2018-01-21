#
# Simple web server that routes requests to views based on URLs.
#

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap'
require 'wunderbar/vue'
require 'ruby2js/es2017/strict'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'
require 'erb'
require 'sanitize'
require 'escape'

require_relative 'personalize'
require_relative 'helpers'
require_relative 'models/mailbox'
require_relative 'models/safetemp'
require_relative 'models/events'
require_relative 'tasks'


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

require 'whimsy/asf'
ASF::Mail.configure

set :show_exceptions, true

disable :logging # suppress log of requests to stderr/error.log

# list of messages
get '/' do
  redirect to('/') if env['REQUEST_URI'] == env['SCRIPT_NAME']

  # determine latest month for which there are messages
  archives = Dir["#{ARCHIVE}/*.yml"].select {|name| name =~ %r{/\d{6}\.yml$}}
  @mbox = archives.empty? ? nil : File.basename(archives.sort.last, '.yml')
  @mbox = [Date.today.strftime('%Y%m'), @mbox].min if @mbox
  @messages = Mailbox.new(@mbox).client_headers.select do |message|
    message[:status] != :deleted
  end

  @cssmtime = File.mtime('public/secmail.css').to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i
  _html :index
end

# alias for root directory
get '/index.html' do
  call env.merge('PATH_INFO' => '/')
end

# support for fetching previous month's worth of messages
get %r{/(\d{6})} do |mbox|
  @mbox = mbox
  _json :index
end

# retrieve a single message
get %r{/(\d{6})/(\w+)/} do |month, hash|
  @message = Mailbox.new(month).headers[hash]
  pass unless @message
  _html :message
end

# task lists
post '/tasklist/:file' do
  @jsmtime = File.mtime('public/tasklist.js').to_i
  @cssmtime = File.mtime('public/secmail.css').to_i

  if request.content_type == 'application/json'
    _json(:"actions/#{params[:file]}")
  else
    @dryrun = JSON.parse(_json(:"actions/#{params[:file]}"))
    _html :tasklist
  end
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end

# mark a single message as deleted
delete %r{/(\d+)/(\w+)/} do |month, hash|
  success = false

  Mailbox.update(month) do |headers|
    if headers[hash]
      headers[hash][:status] = :deleted
      success = true
    end
  end

  pass unless success
  _json success: true
end

# update a single message
patch %r{/(\d{6})/(\w+)/} do |month, hash|
  success = false

  Mailbox.update(month) do |headers|
    if headers[hash]
      updates = JSON.parse(request.env['rack.input'].read)

      # special processing for entries with symbols as keys
      headers[hash].each do |key, value|
        if Symbol === key and updates.has_key? key.to_s
          headers[hash][key] = updates.delete(key.to_s)
        end
      end

      headers[hash].merge! updates
      success = true
    end
  end

  pass unless success
  [204, {}, '']
end

# list of parts for a single message
get %r{/(\d{6})/(\w+)/_index_} do |month, hash|
  message = Mailbox.new(month).find(hash)
  pass unless message
  @attachments = message.attachments
  @headers = message.headers.dup
  @headers.delete :attachments
  @cssmtime = File.mtime('public/secmail.css').to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i
  @projects = (ASF::Podling.current+ASF::Committee.pmcs).map(&:name).sort
  _html :parts
end

# message body for a single message
get %r{/(\d{6})/(\w+)/_body_} do |month, hash|
  @message = Mailbox.new(month).find(hash)
  @cssmtime = File.mtime('public/secmail.css').to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i
  pass unless @message
  _html :body
end

# header data for a single message
get %r{/(\d{6})/(\w+)/_headers_} do |month, hash|
  @headers = Mailbox.new(month).headers[hash]
  pass unless @headers
  _html :headers
end

# raw data for a single message
get %r{/(\d{6})/(\w+)/_raw_} do |month, hash|
  message = Mailbox.new(month).find(hash)
  pass unless message
  [200, {'Content-Type' => 'text/plain'}, message.raw]
end

# intercede for potentially dangerous message attachments
get %r{/(\d{6})/(\w+)/_danger_/(.*?)} do |month, hash, name|
  message = Mailbox.new(month).find(hash)
  pass unless message

  @part = message.find(name)
  pass unless @part

  _html :danger
end

# a specific attachment for a message
get %r{/(\d{6})/(\w+)/(.*?)} do |month, hash, name|
  message = Mailbox.new(month).find(hash)
  pass unless message

  part = message.find(URI.decode(name))
  pass unless part

  [200, {'Content-Type' => part.content_type}, part.body.to_s]
end

# parse memapp-received
get '/memapp.json' do
  _json :memapp
end

# return email for a given id
get '/email.json' do
  _json do
    {email: ASF::Person.find(params[:id]).mail.first}
  end
end

# return a list of iclas
get '/iclas.json' do
  list = []
  ASF::ICLA.each do |icla|
    list << {
      filename: icla.claRef,
      id: icla.id,
      name: icla.name,
      fullname: icla.legal_name,
      email: icla.email
    }
  end
  list.to_json
end

# redirect to an icla
get %r{/icla/(.*)} do |filename|
  checkout = 'https://svn.apache.org/repos/private/documents/iclas'
  iclas = ASF::SVN['private/documents/iclas']
  file = Dir["#{iclas}/#{filename}", "#{iclas}/#{filename}.*"].first
  pass unless file
  redirect to(checkout + '/' + File.basename(file))
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
