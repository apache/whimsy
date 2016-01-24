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
  ruby = File.read(conf)[/PassengerRuby "?(.*?)"?$/, 1] if conf
  if ruby
    passruby = "#{File.dirname(ruby)}/%s#{ruby[/ruby([.\d]*)$/, 1]}"
  else
    passruby = sysruby
  end

  # update gems
  Dir['**/Gemfile'].each do |gemfile|
    Dir.chdir File.dirname(gemfile) do
      ruby = File.read('Gemfile')[/^ruby ['"](.*?)['"]/, 1]
      ruby = `which ruby#{ruby}`.chomp if ruby
      if ruby and not ruby.empty?
        bundler = "#{File.dirname(ruby)}/bundle#{ruby[/ruby([.\d]*)$/, 1]}"
      else
        bundler = (File.exist?('config.ru') ? passruby : sysruby) % 'bundle'
      end

      bundler = 'bundle' unless File.exist?(bundler)
      system "#{bundler} update"
    end
  end

  # determine last update time
  update_file = "#{Process.uid == 0 ? '/root' : Dir.home}/.whimsy-update"
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

task :config do
  $LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
  require 'whimsy/asf/config'
end

namespace :svn do
  task :update => :config do
    repository = YAML.load_file(File.expand_path('../repository.yml', __FILE__))

    # checkout/update svn repositories
    svn = ASF::Config.get(:svn)
    if svn.instance_of? String and svn.end_with? '/*'
      Dir.chdir File.dirname(svn) do
        require 'uri'
        base = URI.parse('https://svn.apache.org/repos/')
        repository[:svn].each do |name, description|
          puts
          puts File.join(Dir.pwd, name)
          if Dir.exist? name
            Dir.chdir(name) {system 'svn cleanup'; system 'svn up'}
          else
            system 'svn', 'checkout', 
              "--depth=#{description['depth'] || 'infinity'}",
              (base + description['url']).to_s, name
          end
        end
      end
    end
  end
end

namespace :git do
  task :pull => :config do
    repository = YAML.load_file(File.expand_path('../repository.yml', __FILE__))

    # clone/pull git repositories
    git = ASF::Config.get(:git)
    if git.instance_of? String and git.end_with? '/*'
      Dir.chdir File.dirname(git) do
        require 'uri'
        base = URI.parse('git://git.apache.org/')
        repository[:git].each do |name, description|
          puts
          puts File.join(Dir.pwd, name)
          if Dir.exist? name
            Dir.chdir(name) {system 'git pull'}
          else
            system 'git', 'clone', (base + description['url']).to_s, name
          end
        end
      end
    end
  end
end
