#
# Simple web server that routes requests to views based on URLs.
#

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap'
require 'wunderbar/react'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'
require 'sanitize'

require_relative 'mailbox'

# list of messages
get '/' do
  # determine latest month for which there are messages
  @mbox = File.basename(Dir["#{ARCHIVE}/*.yml"].sort.last, '.yml')
  _html :index
end

# support for fetching previous month's worth of messages
post '/' do
  _json :index
end

# a single message
get %r{^/(\d+)/(\w+)/$} do |month, hash|
  @message = Mailbox.new(month).headers[hash]
  pass unless @message
  _html :message
end

# list of parts for a single message
get %r{^/(\d+)/(\w+)/_index_$} do |month, hash|
  @message = Mailbox.new(month).headers[hash]
  pass unless @message
  @attachments = @message[:attachments]
  _html :parts
end

# message body for a single message
get %r{^/(\d+)/(\w+)/_body_$} do |month, hash|
  @message = Mailbox.new(month).find(hash)
  pass unless @message
  _html :body
end

# header data for a single message
get %r{^/(\d+)/(\w+)/_headers_$} do |month, hash|
  @headers = Mailbox.new(month).headers[hash]
  pass unless @headers
  _html :headers
end

# a specific attachment for a message
get %r{^/(\d+)/(\w+)/(.*?)$} do |month, hash, name|
  message = Mailbox.new(month).find(hash)
  pass unless message

  part = message.attachments.find do |attach| 
    attach.filename == name or attach['Content-ID'].to_s == name
  end

  pass unless part

  [200, {'Content-Type' => part.content_type}, part.body.to_s]
end
