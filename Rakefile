require 'rubygems/package_task'
require 'open3'

spec = eval(File.read('asf.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

def mkdir_p?(path)
  mkdir_p path unless Dir.exist? path
end

# update gems and restart applications as needed
task :update, [:command] do |task, args|
  # determine last update time of library sources
  lib_update = Dir['lib/**/*'].map {|n| File.mtime n rescue Time.at(0)}.max

  # restart passenger applications that have changed since the last update
  Dir['**/config.ru'].each do |rackapp|
    Dir.chdir File.dirname(rackapp) do
      old_baseline = File.mtime('tmp/restart.txt') rescue Time.at(0)
      last_update = Dir['**/*'].map {|n| File.mtime n rescue Time.at(0)}.max
      if [lib_update, last_update].max > old_baseline and Dir.exist? 'tmp'
        FileUtils.touch 'tmp/.restart.txt'
        FileUtils.chmod 0777, 'tmp/.restart.txt'
        FileUtils.mv 'tmp/.restart.txt', 'tmp/restart.txt'
      end
    end
  end

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

      locktime = File.mtime('Gemfile.lock') rescue Time.at(0)

      bundler = 'bundle' unless File.exist?(bundler)
      system "#{bundler} #{args.command || 'update'}"

      # if new gems were istalled and this directory contains a passenger
      #  application, restart it
      if (File.mtime('Gemfile.lock') rescue Time.at(0)) != locktime
        if File.exist?('tmp/restart.txt')
          FileUtils.touch 'tmp/.restart.txt'
          FileUtils.chmod 0777, 'tmp/.restart.txt'
          FileUtils.mv 'tmp/.restart.txt', 'tmp/restart.txt'
        end
      end
    end
  end

  # rebuild API documentation
  Rake::Task['rdoc'].invoke
end

# pristine version of update
task :pristine do
  Rake::Task[:update].invoke('pristine')
end

# This requires Gems such as Wunderbar to have been set up
task :config do
  $LOAD_PATH.unshift '/srv/whimsy/lib'
  require 'whimsy/asf/config'
  require 'whimsy/asf/git'
  require 'whimsy/asf/svn'
  require 'whimsy/asf/ldap'
end

namespace :svn do
  task :update => :config do
    # Include depth == 'delete'
    svnrepos = ASF::SVN.repo_entries(true) || {}

    # must be outside loop
    PREFIX = '#!:' # must agree with monitors/svn.rb

    # checkout/update svn repositories
    svn = ASF::Config.get(:svn)
    svn = Array(svn).find {|path| String === path and path.end_with? '/*'}
    if svn.instance_of? String and svn.end_with? '/*'
      mkdir_p? File.dirname(svn)
      Dir.chdir File.dirname(svn) do
        svnrepos.each do |name, description|
          puts
          puts File.join(Dir.pwd, name)
          if description['list']
            puts "#{PREFIX} Updating listing file"
            old,new = ASF::SVN.updatelisting(name)
            if old == new
              puts "List is at revision #{old}."
            elsif old == nil
              puts new
            else
              puts "List updated from #{old} to revision #{new}."
            end
          end
          svnpath = ASF::SVN.svnurl(name)
          noCheckout = description['depth'] == 'delete'
          if Dir.exist? name
            if noCheckout
              puts "#{PREFIX} Removing #{name} as it is not intended for checkout"
              FileUtils.rm_rf name                
            else
              curpath = ASF::SVN.getInfoItem(name,'url')
              if curpath != svnpath
                puts "Removing #{name} to correct URL: #{curpath} => #{svnpath}"
                FileUtils.rm_rf name  
              end
            end
          end

          next if noCheckout

          if Dir.exist? name
            Dir.chdir(name) {
              system 'svn cleanup'
              outerr = nil
              # svn update can fail sometimes, so we retry
              2.times do |i|
                if i > 0
                  # log the failure - prefix tells monitor to ignore it
                  puts "#{PREFIX} failed!"
                  outerr.split("\n").each do |l|
                    puts "#{PREFIX} #{l}"                    
                  end
                  n = 10
                  puts "#{PREFIX} will retry in #{n} seconds"
                  sleep n                    
                end
                begin
                  r, w = IO.pipe
                  pid = Process.spawn('svn up', out: w, err: [:child, :out])
                  w.close

                  pid, status = Process.wait2
                  outerr = r.read
                  r.close

                  if status.success?
                    break
                  end
                rescue => e
                  outerr = e.inspect
                  break
                end
              end

              puts outerr # show what happened last
            }
          else
            system 'svn', 'checkout', 
              "--depth=#{description['depth'] || 'infinity'}",
              svnpath, name
          end
        end
      end
    end
  end

  task :check => :config do
    # check if the svn repositories have been set up OK
    svnrepos = ASF::SVN.repo_entries || {}
    errors = 0
    svn = ASF::Config.get(:svn)
    if svn.instance_of? String and svn.end_with? '/*'
      Dir.chdir File.dirname(svn) do
        svnrepos.each do |name, description|
          puts
          puts File.join(Dir.pwd, name)
          if Dir.exist? name
            Dir.chdir(name) {
              outerr = nil
                begin
                  outerr, status = Open3.capture2e('svn info --show-item url')
                  if status.success?
                    outerr.chomp!
                    if outerr.end_with? description['url']
                       puts "#{outerr} - OK"
                       break
                    else
                       puts "#{outerr} - Error!\nExpected URL to end with:    #{description['url']}"
                       errors += 1
                    end
                    break
                  end
                rescue => e
                  outerr = e.inspect
                  errors += 1
                  break
                end
              puts outerr # show what happened last
            }
          else
            require 'uri'
            base = URI.parse('https://svn.apache.org/repos/')
            puts "Directory not found - expecting checkout of #{(base + description['url']).to_s}"
            errors += 1
          end
        end
      end
      puts
      if errors > 0
        puts "** Found #{errors} error(s) **"
      else
        puts "** No errors found **"
      end
    end
  end

end

namespace :git do
  task :pull => :config do
    gitrepos = ASF::Git.repo_entries() || {}

    # clone/pull git repositories
    git = ASF::Config.get(:git)
    if git.instance_of? String and git.end_with? '/*'
      mkdir_p File.dirname(git)
      Dir.chdir File.dirname(git) do
        require 'uri'
        base = URI.parse('git://git.apache.org/')
        gitrepos.each do |name, description|
          branch = description['branch']

          puts
          puts File.join(Dir.pwd, name)

          if Dir.exist? name
            Dir.chdir(name) do
              # update the location of the remote, if necessary
              remote = `git config --get remote.origin.url`.chomp
              if remote != (base + description['url']).to_s
                `git config remote.origin.url #{base + description['url']}`
              end

              # pull changes
              system "git checkout #{branch}" if branch
              system 'git fetch origin'
              system "git reset --hard origin/#{branch || 'master'}"
            end
          else
            # fresh checkout
            system 'git', 'clone', (base + description['url']).to_s, name
            Dir.chdir(name) {system "git checkout #{branch}"} if branch
          end
        end
      end
    end
  end
end

# update documentation
task :rdoc => 'www/docs/api/index.html'
file 'www/docs/api/index.html' => Rake::FileList['lib/**/*.rb'] do
  Dir.chdir File.dirname(__FILE__) do
    system 'rdoc', 'lib', '--output', 'www/docs/api', '--force-output',
      '--title', 'whimsy/asf lib'
  end
end

# Travis support: run the tests associated with the bundle in question
task :default do
  bg = ENV['BUNDLE_GEMFILE']
  if bg and bg != __FILE__
    Dir.chdir File.dirname(bg) do
      sh 'rake test'
    end
  end
end

# Docker support
namespace :docker do
  task :build => 'docker/work/whimsy.conf' do
    Dir.chdir File.join(__dir__, 'docker') do
      sh 'docker-compose build web'
    end
  end

  task :update => :build do
    Dir.chdir File.join(__dir__, 'docker') do
      sh 'docker-compose run  --entrypoint ' +
        %('bash -c "rake docker:scaffold && rake update"') +
        ' web'
    end
  end

  task :up do
    Dir.chdir File.join(__dir__, 'docker') do
      sh 'docker-compose up'
    end
  end

  task :exec do
    Dir.chdir File.join(__dir__, 'docker') do
      sh 'docker-compose exec web /bin/bash'
    end
  end

  # cannot depend on :config
  task :scaffold do
    # set up symlinks from /root to user's home directory
    home = ENV['HOST_HOME']
    if home and File.exist? home
      %w(.gitconfig .ssh .subversion).each do |mount|
        if File.exist? "/root/#{mount}"
          if File.symlink? "/root/#{mount}"
            next if File.realpath("/root/#{mount}") == "#{home}/#{mount}"
            rm_f "/root/#{mount}"
          else
            rm_rf "/root/#{mount}"
          end
        end

        symlink "#{home}/#{mount}", "/root/#{mount}"
      end
    end

    # This should already exist, but just in case
    mkdir_p? '/srv/whimsy/www/members'

    unless File.exist? '/srv/whimsy/www/members/log'
      ln_s '/var/log/apache2', '/srv/whimsy/www/members/log'
    end

    begin
      mode = File.stat('/var/log/apache2').mode
      if mode & 7 != 5
        chmod 0755, '/var/log/apache2'
      end
    rescue
    end

    # Create other needed directories
    mkdir_p? '/srv/cache'
    mkdir_p? '/srv/mail/secretary'
    # there may be more

  end

  task :entrypoint => [:scaffold, :config] do
    # requires :config
    unless File.read(File.join(ASF::ETCLDAP,'ldap.conf')).include? 'asf-ldap-client.pem'
      sh 'ruby -I lib -r whimsy/asf -e "ASF::LDAP.configure"'
    end
    sh 'apache2ctl -DFOREGROUND'
  end
end

file 'docker/work' do
  mkdir_p 'docker/work'
end

file 'docker/work/whimsy.conf' => ['docker/work', 'config/whimsy.conf'] do
  cp 'config/whimsy.conf', 'docker/work/whimsy.conf'
end
