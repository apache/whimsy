#!/usr/bin/env ruby
#
# Watch for updates to sources to passenger applications, and restart those
# applications whenever changes occur.
#

require 'listen'
require 'fileutils'

watch = Hash.new {|hash, key| hash[key] = []}

Dir["#{File.expand_path('../..', __FILE__)}/**/restart.txt"].each do |restart|
  app = File.expand_path('../..', restart)
  next unless File.exist? "#{app}/config.ru"

  watch[app] << restart

  if File.exist? "#{app}/Gemfile.lock"
    paths = File.read("#{app}/Gemfile.lock")[/^PATH.*?\n\n/m].to_s
    libs = paths.scan(/^\s*remote: (.*)/).flatten.map {|path| path+'/lib'}
    libs.each {|lib| watch[lib] << restart}
  end
end

listener = Listen.to(*watch.keys) do |modified, added, removed|
  touches = []
  (modified + added + removed).each do |file|
    watch.each do |path, restarts|
      touches += restarts if file.start_with? path + '/'
    end
  end

  touches.uniq.each do |restart|
    FileUtils.touch restart
  end
end

listener.ignore /~$/
listener.ignore /^\..*\.sw\w$/
listener.ignore /passenger.\d+\.(log|pid(\.lock)?)$/

listener.start
sleep
