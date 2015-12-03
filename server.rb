require 'whimsy/asf'
require 'wunderbar/sinatra'

require_relative 'config'

def load_mbox(file)
  messages = YAML.load_file(file)
  messages.delete :mtime
  source = File.basename(file, '.yml')
  messages.each do |key, value|
    value[:source]=source
  end
end

get '/' do
  @messages = load_mbox(Dir["#{ARCHIVE}/*.yml"].sort.last)
  @messages.merge! load_mbox(Dir["#{ARCHIVE}/*.yml"].sort[-2])

  @messages = @messages.sort_by {|id, message| message[:time]}.reverse

  _html :index
end
