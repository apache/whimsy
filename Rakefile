verbose false

file 'Gemfile.lock' => 'Gemfile' do
  sh 'bundle update'
end

task :parse => 'Gemfile.lock' do
  ruby 'parsemail.rb'
end

task :fetch => 'Gemfile.lock' do
  ruby 'parsemail.rb', '--fetch'
end
