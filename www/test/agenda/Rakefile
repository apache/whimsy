require 'whimsy/asf/config'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec
task :spec => :work

task :server do
  ENV['RACK_ENV']='development'
  require 'wunderbar/listen'
end

namespace :server do
  task :test do
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

task :work => ['test/work/board', 'test/work/data/test.yml']

task :test => :work do
end

task :clobber do
  rm_rf 'test/work'
end
