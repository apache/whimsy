##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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
    puts "Reponse differs:"
    puts previous
    puts response
  end
  puts JSON.pretty_generate(response)
end
