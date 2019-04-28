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

class Pending
  # determine the name of the work file associated with a given user
  def self.work_file(user)
    "#{AGENDA_WORK}/#{user}.yml".untaint if user =~ /\A\w+\z/
  end

  # fetch and parse a work file
  def self.get(user, agenda=nil)

    file = work_file(user)
    response = ((file and File.exist?(file)) ? YAML.load_file(file) : {})

    # reset pending when agenda changes
    if agenda and agenda > response['agenda'].to_s
      response = {'agenda' => agenda, 'initials' => response['initials']}
    end

    # provide empty defaults
    response['approved'] ||= []
    response['unapproved'] ||= []
    response['flagged'] ||= []
    response['unflagged'] ||= []
    response['comments'] ||= {} 
    response['seen']     ||= {}

    # extract user information
    response['userid'] ||= user

    if user == 'test' and ENV['RACK_ENV'] == 'test'
      username = 'Joe Tester'
    else
      username = ASF::Person.new(user).public_name
      begin
        username ||= Etc.getpwnam(user)[4].split(',')[0].
          force_encoding('utf-8')
      rescue ArgumentError
        username = 'Anonymous'
      end
    end

    if user == 'test' or ASF::Service['board'].members.map(&:id).include? user
      response['role'] = :director
    elsif ASF::Service['asf-secretary'].members.map(&:id).include? user
      response['role'] = :secretary
    else
      response['role'] = :guest
    end

    response['username'] ||= username
    response['initials'] ||= username.gsub(/[^A-Z]/, '').downcase
    response['firstname'] ||= username.split(' ').first.downcase

    # return response
    response
  end

  # update a work file
  def self.update(user, agenda=nil)
    pending = self.get(user, agenda)

    yield pending

    work = work_file(user)
    File.open(work, 'w') do |file|
      file.write YAML.dump(pending)
    end

    pending
  end
end
