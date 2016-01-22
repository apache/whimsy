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

testfiles = %w(board_minutes_2015_01_21 board_minutes_2015_02_18 test)
testfiles.each do |testfile|
  file "test/work/data/#{testfile}.yml" do
    mkdir_p 'test/work/data' unless File.exist? 'test/work/data'
    cp "test/#{testfile}.yml", "test/work/data/#{testfile}.yml"
  end
end

task :reset do
  testfiles.each do |testfile|
    if File.exist? "test/work/data/#{testfile}.yml"
      if 
        IO.read("test/#{testfile}.yml") != 
        IO.read("test/work/data/#{testfile}.yml")
      then
        rm "test/work/data/#{testfile}.yml"
      end
    end
  end

  if
    Dir['test/work/board/*'].any? do |file|
      base = "test/data/#{File.basename file}"
      not File.exist?(base) or IO.read(base) != IO.read(file)
    end
  then
    rm_rf 'test/work/board'
  end

  unless Dir.exist? 'test/work/board'
    rm_rf 'test/work/repository'
  end
end

task :work => ['test/work/board', 
  *testfiles.map {|testfile| "test/work/data/#{testfile}.yml"}]

namespace :test do
  task :setup => [:reset, :work]
  task :server => 'server:test'
end

task :clobber do
  rm_rf 'test/work'
end

task :update do
  # update agenda application
  Dir.chdir File.dirname(__FILE__) do
    puts "#{File.dirname(File.realpath(__FILE__))}:"
    system 'git pull'
  end
  
  # update libs
  if File.exist? "#{ENV['HOME']}/.whimsy"
    libs = YAML.load_file("#{ENV['HOME']}/.whimsy")[:lib] || []
    libs.each do |lib|
      puts "\n#{lib}:"
      if not File.exist? lib
        puts 'not found'
        next
      end

      # determine repository type
      repository = :none
      parent = File.realpath(lib)
      while repository == :none and parent != '/'
        if File.exist? File.join(parent, '.svn')
          repository = :svn
        elsif File.exist? File.join(parent, '.git')
          repository = :git
        else
          parent = File.dirname(parent)
        end
      end

      # update repository
      Dir.chdir lib do
        system 'svn up' if repository == :svn
        system 'git pull' if repository == :git
      end
    end
  end

  # update gems
  puts "\nbundle update:"
  system 'bundle update'
end

namespace :svn do
  task :update do
    ASF::Config.get(:svn).each do |svn|
      if Dir.exist? svn
        puts "\n#{svn}:"
        Dir.chdir(svn) {system 'svn up'}
      end
    end
  end
end
