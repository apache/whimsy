require_relative 'config'

verbose false

task :default do
  puts 'Usage:'
  sh 'rake', '-T'
end

file 'Gemfile.lock' => 'Gemfile' do
  sh 'bundle update'
end

desc 'install dependencies'
task :bundle => 'Gemfile.lock'

desc 'Parse emails'
task :parse => :bundle do
  ruby 'parsemail.rb'
end

desc 'Fetch and parse emails'
task :fetch => :bundle do
  ruby 'parsemail.rb', '--fetch'
end

desc 'WebServer that provides an interface to explore emails'
task :server => :bundle do
  require 'whimsy/asf/config'
  ENV['RACK_ENV']='development'
  require 'wunderbar/listen'
end

desc 'remove all parsed yaml files'
task :clean do
  rm_rf Dir["#{ARCHIVE}/*.yml"]
end
