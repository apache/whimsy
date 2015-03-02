require 'whimsy/asf/config'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec
task :spec => :work

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
task :work => ['test/work/board', 'test/work/data']

task :test => :work do
end

task :clobber do
  rm_rf 'test/work'
end
