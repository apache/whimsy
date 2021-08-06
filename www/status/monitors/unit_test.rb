# unit test helper

require 'json'

# fetch the status file and extract the previous sample, then call the method
# the same string is used to extract the sample and call the method
def runtest(method_name)
  status_file = File.expand_path('../../status.json', __FILE__)
  baseline = JSON.parse(File.read(status_file),{symbolize_names: true}) rescue {}
  baseline[:data] = {} unless baseline[:data].instance_of? Hash
  previous = baseline[:data][method_name.to_sym] || {mtime: Time.at(0)}
  response = Monitor.send(method_name, previous)
  if response == previous
    puts "No change in response"
  elsif response[:data] and response[:data] == previous[:data]
    # main class adds a trailer after the data
    puts "No change in response data"
  else
    puts "Response differs:"
    puts previous
    puts response
  end
  puts JSON.pretty_generate(response)
end
