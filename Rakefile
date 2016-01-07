require 'rubygems/package_task'

spec = eval(File.read('asf.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

# update gems and restart applications as needed
task :update do
  # locate system ruby
  sysruby = File.realpath(`which ruby`.chomp)
  sysruby = "#{File.dirname(sysruby)}/%s#{sysruby[/ruby([.\d]*)$/, 1]}"

  # locate passenger ruby
  conf = Dir['/etc/apache2/*/passenger.conf'].first
  conf = File.read(conf)[/PassengerDefaultRuby (.*)/, 1] if conf
  if conf
    passruby = "#{File.dirname(conf)}/%s#{conf[/ruby([.\d]*)$/, 1]}"
  else
    passruby = sysruby
  end

  # update gems
  Dir['**/Gemfile'].each do |gemfile|
    Dir.chdir File.dirname(gemfile) do
      bundler = (File.exist?('config.ru') ? passruby : sysruby) % 'bundle'
      bundler = (File.exist?(bundler) ? bundler : 'bundle')
      system "#{bundler} update"
    end
  end

  # determine last update time
  update_file = "#{Dir.home}/.whimsy-update"
  new_baseline = Time.now
  old_baseline = File.mtime(update_file) rescue Time.at(0)

  # restart passenger applications that have changed since the last update
  Dir['**/config.ru'].each do |rackapp|
    Dir.chdir File.dirname(rackapp) do
      last_update = Dir['**/*'].map {|n| File.mtime n rescue Time.at(0)}.max
      if last_update > old_baseline and Dir.exist? 'tmp'
        FileUtils.touch 'tmp/.restart.txt'
        FileUtils.chmod 0777, 'tmp/.restart.txt'
        FileUtils.mv 'tmp/.restart.txt', 'tmp/restart.txt'
      end
    end
  end

  # update baseline time
  FileUtils.touch update_file
  File.utime new_baseline, new_baseline, update_file
end
