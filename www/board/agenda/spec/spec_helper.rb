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
# common test setup
#

# prepend whimsy/lib to library search path
lib = File.expand_path('../' * 5 + 'lib', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib

ENV['RACK_ENV'] = 'test'
ENV['REMOTE_USER'] = 'test'
require 'capybara/rspec'
require "selenium-webdriver"
require_relative '../main'
Capybara.app = Sinatra::Application
Capybara.javascript_driver = :selenium_chrome_headless

require 'whimsy/asf/rack'

module MockServer
  # wunderbar environment
  def _
    self
  end

  # sinatra environment
  def env
    Struct.new(:user, :password).new('test', nil)
  end

  # capture wunderbar 'json' output methods
  def method_missing(method, *args, &block)
    if method =~ /^_(\w+)$/ and args.length == 1
      instance_variable_set "@#$1", args.first
    else
      super
    end
  end

  # run system commands, appending output to transcript.
  # intercept commits, adding the files to the cleanup list
  def system(*args)
    args.flatten!
    if args[1] == 'commit'
      @commits ||= {}
      @commits[File.basename args[2]] = File.read(args[2])
      `svn revert #{args[2]}`
      0
    else
      args.reject! {|arg| Array === arg}
      @transcript ||= ''
      @transcript += `#{Shellwords.join(args)}`
      $?.exitstatus
    end
  end
end

RSpec.configure do |config|
  config.include MockServer

  config.before(:each) do
    FileUtils.rm_rf Agenda::CACHE
    FileUtils.mkdir_p Agenda::CACHE
  end
end
