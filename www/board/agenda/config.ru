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

require 'whimsy/asf/rack'

require File.expand_path('../main.rb', __FILE__)

# https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/asf/rack.rb
use ASF::Auth::MembersAndOfficers do |env|
  # allow access to bootstrap related content
  if 
    env['PATH_INFO'] =~ %r{^/(app|sw)\.js(\.map)?$} or
    env['PATH_INFO'] =~ %r{\.js\.rb?$} or
    env['PATH_INFO'] =~ %r{^/stylesheets/.*\.css\$} or
    env['PATH_INFO'] =~ %r{^/[-\d]+/bootstrap.html$} or
    env['PATH_INFO'] == '/manifest.json'
  then
    next true
  end

  # additionally authorize all invited guests
  agenda = dir('board_agenda_*.txt').sort.last
  if agenda
    Agenda.parse(agenda, :full)
    roll = Agenda[agenda][:parsed].find {|item| item['title'] == 'Roll Call'}
    roll['people'].keys.include? env['REMOTE_USER']
  end
end

use ASF::HTTPS_workarounds

use ASF::ETAG_Deflator_workaround

use ASF::DocumentRoot

run Sinatra::Application
