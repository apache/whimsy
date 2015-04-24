require 'whimsy/asf/config'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec
task :spec => 'test:setup'
task :test => :spec

task :server do
  ENV['RACK_ENV']='development'
  require 'wunderbar/listen'
end

namespace :server do
  task :test => :work do
    ENV['RACK_ENV']='test'
    ENV['USER']='test'
    require 'wunderbar/listen'
  end
end

file 'test/work' do
  mkdir_p 'test/work'
end

file 'test/work/repository' => 'test/work' do
  unless File.exist? 'test/work/repository/format'
    system 'svnadmin create test/work/repository'
  end
end

file 'test/work/board' => 'test/work/repository' do
  Dir.chdir('test/work') do
    rm_rf 'board' if File.exist? 'board'
    system "svn co file:///#{Dir.pwd}/repository board"
    cp Dir['../data/*.txt'], 'board'
    Dir.chdir('board') {system 'svn add *.txt; svn commit -m "initial commit"'}
  end
end

file 'test/work/data' => 'test/work' do
  mkdir_p 'test/work/data'
end

file 'test/work/data/test.yml' => 'test/work/data' do
  cp 'test/test.yml', 'test/work/data/test.yml'
end

task :reset do
  if File.exist? 'test/work/data/test.yml'
    if IO.read('test/test.yml') != IO.read('test/work/data/test.yml')
      rm 'test/work/data/test.yml'
    end
  end

  if
    Dir['test/work/board/*'].any? do |file|
      IO.read("test/data/#{File.basename file}") != IO.read(file)
    end
  then
    rm_rf 'test/work/board'
  end

  if
    Dir['test/work/repository/db/revs/0/*'].length > 2
  then
    rm_rf 'test/work/repository'
  end
end

task :work => ['test/work/board', 'test/work/data/test.yml']

namespace :test do
  task :setup => [:reset, :work]
  task :server => 'server:test'
end

task :clobber do
  rm_rf 'test/work'
end
