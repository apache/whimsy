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
