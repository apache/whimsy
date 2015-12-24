#
# Simple web server that routes requests to views based on URLs.
#

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap'
require 'wunderbar/react'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'
require 'sanitize'

require_relative 'models/mailbox'

# list of messages
get '/' do
  # determine latest month for which there are messages
  archives = Dir["#{ARCHIVE}/*.yml"].select {|name| name =~ %r{/\d{6}\.yml$}}
  @mbox = File.basename(archives.sort.last, '.yml')
  _html :index
end

# support for fetching previous month's worth of messages
get %r{^/(\d{6})$} do |mbox|
  @mbox = mbox
  _json :index
end

# retrieve a single message
get %r{^/(\d{6})/(\w+)/$} do |month, hash|
  @message = Mailbox.new(month).headers[hash]
  pass unless @message
  _html :message
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end

# mark a single message as deleted
delete %r{^/(\d+)/(\w+)/$} do |month, hash|
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
patch %r{^/(\d{6})/(\w+)/$} do |month, hash|
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
get %r{^/(\d{6})/(\w+)/_index_$} do |month, hash|
  message = Mailbox.new(month).find(hash)
  pass unless message
  @attachments = message.attachments
  @headers = message.headers.dup
  @headers.delete :attachments
  _html :parts
end

# message body for a single message
get %r{^/(\d{6})/(\w+)/_body_$} do |month, hash|
  @message = Mailbox.new(month).find(hash)
  pass unless @message
  _html :body
end

# header data for a single message
get %r{^/(\d{6})/(\w+)/_headers_$} do |month, hash|
  @headers = Mailbox.new(month).headers[hash]
  pass unless @headers
  _html :headers
end

# a specific attachment for a message
get %r{^/(\d{6})/(\w+)/(.*?)$} do |month, hash, name|
  message = Mailbox.new(month).find(hash)
  pass unless message

  part = message.find(name)
  pass unless part

  [200, {'Content-Type' => part.content_type}, part.body.to_s]
end
