# unit test helper

require 'json'

# fetch the status file and extract the previous sample, then call the method
# the same string is used to extract the sample and call the method
def runtest(method_name)
  status_file = File.expand_path('../../status.json', __FILE__)
  baseline = JSON.parse(File.read(status_file)) rescue {}
  baseline['data'] = {} unless baseline['data'].instance_of? Hash
  previous = baseline['data'][method_name] || {mtime: Time.at(0)}
  puts JSON.pretty_generate(Monitor.send(method_name, previous))
end
