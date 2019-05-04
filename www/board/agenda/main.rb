#!/usr/bin/env ruby
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


#
# Server side setup
#

require 'whimsy/asf/agenda'
require 'whimsy/asf/board'

require 'wunderbar/sinatra'
require 'wunderbar/vue'
require 'wunderbar/bootstrap/theme'
require 'ruby2js/es2015'
require 'ruby2js/strict'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require 'listen'
require 'yaml'
require 'thread'
require 'net/http'
require 'shellwords'
require 'mail'
require 'open-uri'
require 'erubis'

unless ENV['RACK_ENV'] == 'development'
  disable :logging # suppress log of requests to stderr/error.log
end

# determine where relevant data can be found
if ENV['RACK_ENV'] == 'test'
  FOUNDATION_BOARD = File.expand_path('test/work/board').untaint
  AGENDA_WORK = File.expand_path('test/work/data').untaint
  STDERR.puts "* SVN board  : #{FOUNDATION_BOARD}"
  STDERR.puts "* Agenda work: #{AGENDA_WORK}"
else
  FOUNDATION_BOARD = ASF::SVN['foundation_board']
  AGENDA_WORK = ASF::Config.get(:agenda_work).untaint || '/srv/agenda'
  STDERR.puts "* SVN board  : #{FOUNDATION_BOARD}"
  STDERR.puts "* Agenda work: #{AGENDA_WORK}"
end

FileUtils.mkdir_p AGENDA_WORK if not Dir.exist? AGENDA_WORK

require_relative './routes'
require_relative './models/pending'
require_relative './models/agenda'
require_relative './models/minutes'
require_relative './models/comments'
require_relative './helpers/string'
require_relative './helpers/integer'
require_relative './daemon/session'
require_relative './daemon/events'

require 'websocket-client-simple'

# if AGENDA_WORK doesn't exist yet, make it
if not Dir.exist? AGENDA_WORK
  require 'fileutils'
  FileUtils.mkdir_p AGENDA_WORK
end

# get a directory listing given a pattern and a base directory
def dir(pattern, base=FOUNDATION_BOARD)
  Dir[File.join(base, pattern)].map {|name| File.basename name}
end

# workaround for https://github.com/rubygems/rubygems/issues/1265
if Gem::Specification.respond_to? :stubs
  Gem::Specification.stubs.each do |stub|
    stub.full_require_paths.each {|path| path.untaint}
  end
end
