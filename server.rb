require 'whimsy/asf'
require 'wunderbar/sinatra'
require 'mail'

require_relative 'mailbox'

def load_mbox(file)
  messages = YAML.load_file(file)
  messages.delete :mtime
  source = File.basename(file, '.yml')
  messages.each do |key, value|
    value[:source]=source
  end
end

def load_message(month, hash)
  mbox = Dir["#{ARCHIVE}/#{month}", "#{ARCHIVE}/#{month}.gz"].first
  return unless mbox

  mbox = Mailbox.new(mbox)
  mbox.each do |message|
    if Mailbox.hash(message) == hash
      return Mail.read_from_string(message) 
    end
  end
end

get '/' do
  @messages = load_mbox(Dir["#{ARCHIVE}/*.yml"].sort.last)
  @messages.merge! load_mbox(Dir["#{ARCHIVE}/*.yml"].sort[-2])

  @messages = @messages.sort_by {|id, message| message[:time]}.reverse

  _html :index
end

get %r{^/(\d+)/(\w+)/$} do |month, hash|
  @message = load_mbox("#{ARCHIVE}/#{month}.yml")[hash] rescue pass
  _html :message
end

get %r{^/(\d+)/(\w+)/_index_$} do |month, hash|
  @message = load_mbox("#{ARCHIVE}/#{month}.yml")[hash] rescue pass
  _html :parts
end

get %r{^/(\d+)/(\w+)/_body_$} do |month, hash|
  @message = load_message(month, hash)
  pass unless @message
  _html :body
end

get %r{^/(\d+)/(\w+)/_headers_$} do |month, hash|
  @headers = load_mbox("#{ARCHIVE}/#{month}.yml")[hash] rescue pass
  pass unless @headers
  _html :headers
end

get %r{^/(\d+)/(\w+)/(.*?)$} do |month, hash, name|
  message = load_message(month, hash)
  pass unless message
  part = message.attachments.find {|attach| attach.filename == name}
  pass unless part

  [200, {'Content-Type' => part.content_type}, part.body.to_s]
end
