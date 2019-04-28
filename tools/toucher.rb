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
# Watch for updates to sources to passenger applications, and restart those
# applications whenever changes occur.
#

require 'listen'
require 'fileutils'

watch = Hash.new {|hash, key| hash[key] = []}

Dir["#{File.expand_path('../..', __FILE__)}/**/config.ru"].each do |config|
  app = File.expand_path('..', config)
  FileUtils.mkdir_p "#{app}/tmp"
  restart = "#{app}/tmp/restart.txt"

  watch[File.realpath(app)] << restart

  if File.exist? "#{app}/Gemfile.lock"
    paths = File.read("#{app}/Gemfile.lock").scan(/^PATH.*?\n\n/m).join
    libs = paths.scan(/^\s*remote: (.*)/).flatten.map {|path| path+'/lib'}
    libs.each {|lib| watch[lib] << restart}
  end
end

watched = watch.keys.select {|dir| Dir.exist? dir}
listener = Listen.to(*watched) do |modified, added, removed|
  restart = false
  touches = []
  (modified + added + removed).each do |file|
    restart ||= (File.basename(file) == "Gemfile.lock")
    watch.each do |path, restarts|
      touches += restarts if file.start_with? path + '/'
    end
  end

  touches.uniq.each do |restart|
    FileUtils.touch restart
  end

  if restart
    require 'rbconfig'
    exec RbConfig.ruby, __FILE__, *ARGV
  end
end

listener.ignore /~$/
listener.ignore /^\..*\.sw\w$/
listener.ignore /passenger.\d+\.(log|pid(\.lock)?)$/

listener.start
sleep
