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

require 'net/http'
require 'whimsy/asf/rack'
require 'thread'

Dir.chdir File.expand_path('../..', __FILE__)
system 'rake test:setup'

# start server
ENV['RACK_ENV'] = 'test'
pid = fork { exec 'passenger start' }

# make sure server is cleaned up on exit
at_exit do
  # shut down
  Process.kill 'INT', pid
  Process.waitpid pid
end

# wait for server to start
10.times do |i|
  begin
    Net::HTTP.get_response(URI.parse("http://localhost:3000/"))
    break
  rescue Errno::ECONNREFUSED
  end
  sleep i*0.1
end

# everybody approve tomcat
threads = ASF::Service['board'].members.map do |person|
  userid = person.id
  initials = person.public_name.gsub(/[^A-Z]/, '').downcase

  Thread.new do
    File.unlink "test/work/data/#{userid}.yml" rescue nil

    # approve tomcat
    uri = URI.parse("http://localhost:3000/json/approve")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.basic_auth(userid, "password")
    request.set_form_data agenda: "board_agenda_2015_02_18.txt",
      initials: initials, request: 'approve', attach: 'BX'
    response = http.request(request)

    # commit
    uri = URI.parse("http://localhost:3000/json/commit")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.basic_auth(userid, "password")
    request.set_form_data message: "approve tomcat", initials: initials
    response = http.request(request)
    # File.write("#{userid}.response", response.body.force_encoding('utf-8'))
  end
end

# wait for threads to complete
threads.each {|thread| thread.join}

# verify approvals
agenda = File.read('test/work/board/board_agenda_2015_02_18.txt')
approvals = agenda[/Tomcat\.\s+approved: (.*)/, 1]
print approvals.inspect + ' ...'
expected = ASF::Service['board'].members.map do |person|
   person.public_name.gsub(/[^A-Z]/, '').downcase
end
if approvals.split(/,\s*/).sort == expected.sort
  puts 'success'
else
  puts 'failure'
  exit
end
