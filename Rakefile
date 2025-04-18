require 'open3'

SERVICE='web'  # name must agree with services entry in docker-compose.yaml

# N.B. this file must be invoked from its containing directory.
# It assumes that it will be run from the top of the Whimsy code tree

def mkdir_p?(path)
  mkdir_p path unless Dir.exist? path
end

# Run system and abort if it fails
def system!(*args)
  system(*args) or raise 'system!() failed!'
end

# update gems and restart applications as needed
task :update, [:command] do |_task, args|
  # determine last update time of library sources
  lib_update = Dir['lib/**/*'].map {|n| File.mtime n rescue Time.at(0)}.max

  # restart passenger applications that have changed since the last update
  # If a Gem is later updated below, any passenger app is restarted again.
  # Most of the time, no Gems are installed, so this deploys changes quicker
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
  # N.B. The %s is used to insert related commands such as 'bundle' later on
  sysruby = File.join(File.dirname(sysruby), "%s#{sysruby[/ruby([.\d]*)$/, 1]}")

  # locate passenger ruby
  conf = Dir['/etc/apache2/*/passenger.conf'].first
  ruby = File.read(conf)[/PassengerRuby "?(.*?)"?$/, 1] if conf
  if ruby
    # create the base format string
    passruby = File.join(File.dirname(ruby), "%s#{ruby[/ruby([.\d]*)$/, 1]}")
  else
    passruby = sysruby
  end

  require 'bundler'
  unless Bundler.bundle_path.writable?
    # collect up all gems and install them so the sudo password is only
    # asked for once
    gemlines = Dir['**/Gemfile'].
      map {|file| File.read file}.join.scan(/^\s*gem\s.*/)

    if File.exist? 'asf.gemspec'
      gemlines +=
        File.read('asf.gemspec').scan(/add_dependency\((.*)\)/).
        map {|(line)| "gem #{line}"}
    end

    gems = gemlines.map {|line| [line[/['"](.*?)['"]/, 1], line.strip]}.to_h
    gems['whimsy-asf'].sub!(/,.*/, ", path: #{Dir.pwd.inspect}")

    ldapname =
    begin
      File.read(File.expand_path('../asfldap.gemname', __FILE__)).strip
    rescue Exception => e
      'ruby-ldap'
    end

    # Also need to define version for wunderbar as per the asf.gemspec file
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        contents = [
          "source 'https://rubygems.org'",
          "ldapname = '#{ldapname}'",
          'ldapversion = nil', # Needed for initial gem setup
          gems.values
        ].join("\n")
        File.write 'Gemfile', contents
        $stderr.puts '* Preloading gems...'
        system!('bundle', 'install')
        $stderr.puts '* ... done'
      end
    end
  end

  # update gems
  $stderr.puts '* Update Gems' # use stderr so output appears in syslog
  Dir['**/Gemfile'].each do |gemfile|
    Dir.chdir File.dirname(gemfile) do
      ruby = File.read('Gemfile')[/^ruby ['"](.*?)['"]/, 1]
      ruby = `which ruby#{ruby}`.chomp if ruby
      if ruby and not ruby.empty?
        bundler = File.join(File.dirname(ruby), "bundle#{ruby[/ruby([.\d]*)$/, 1]}")
      else
        bundler = (File.exist?('config.ru') ? passruby : sysruby) % 'bundle'
      end

      locktime = File.mtime('Gemfile.lock') rescue Time.at(0)

      bundler = 'bundle' unless File.exist?(bundler)
      $stderr.puts "* Processing #{gemfile}"
      system!(bundler, args.command || 'update')

      # if new gems were installed and this directory contains a passenger
      #  application, restart it
      if (File.mtime('Gemfile.lock') rescue Time.at(0)) != locktime
        $stderr.puts '* Gemfile.lock was updated'
        if File.exist?('tmp/restart.txt')
          FileUtils.touch 'tmp/.restart.txt'
          FileUtils.chmod 0o777, 'tmp/.restart.txt'
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
  $LOAD_PATH.unshift 'lib'
  require 'wunderbar'
  require 'whimsy/asf/config'
  require 'whimsy/asf/git'
  require 'whimsy/asf/svn'
  require 'whimsy/lockfile'
end

namespace :svn do
  task :update, [:arg1] => :config do |task, args|
    arg1 = args.arg1 || '' # If defined, it is either the name of a checkout to update or 'skip'
    options = [arg1, args.extras].flatten # capture all options
    # Include all
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
          # skip the update unless it matches the parameter (if any) provided
          # 'skip' is special and means update all list files
          # The empty string means no options provided
          next unless ['skip', ''].include?(arg1)  || options.include?(name)
          puts
          puts File.join(Dir.pwd, name)
          if description['list']
            puts "#{PREFIX} Updating listing file"
            old,new = ASF::SVN.updatelisting(name,nil,nil,description['dates'])
            if old == new
              puts "List is at revision #{old}."
            elsif old.nil?
              puts new
            else
              puts "List updated from #{old} to revision #{new}."
            end
          end
          svnpath = ASF::SVN.svnurl(name)
          depth = description['depth'] || 'infinity'
          noCheckout = %w(delete skip).include? depth
          if Dir.exist? name
            if noCheckout
              puts "#{PREFIX} Removing #{name} as it is not intended for checkout"
              FileUtils.rm_rf name # this will remove symlink only (on macOS at least)
            else
              curpath = ASF::SVN.getInfoItem(name,'url')
              if curpath != svnpath
                puts "Removing #{name} to correct URL: #{curpath} => #{svnpath}"
                FileUtils.rm_rf name  # this will remove symlink only (on macOS at least)
              end
            end
          end

          next if arg1 == 'skip'
          if noCheckout
            puts 'Skipping' if depth == 'skip' # Must agree with monitors/svn.rb
            next
          end

          files = description['files']
          if Dir.exist? name
            isSymlink = File.symlink?(name) # we don't want to change such checkouts
            Dir.chdir(name) {
             # ensure single-threaded SVN updates
             LockFile.lockfile(Dir.pwd, nil, File::LOCK_EX) do # ignore the return parameter
              system!('svn', 'cleanup')
              unless isSymlink # Don't change depth for symlinks
                curdepth = ASF::SVN.getInfoAsHash('.')['Depth'] || 'infinity' # not available as separate item
                if curdepth != depth
                  puts "#{PREFIX} update depth from '#{curdepth}' to '#{depth}'"
                  system!('svn', 'update', '--set-depth', depth)
                end
              end
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
                  # Note: list the files to update to cater for later additions
                  # Also update '.' so parent directory shows last changed revision for status/svn page
                  svncmd = %w(svn update .)
                  # '.' is redundant if files not present, but it simplifies logic
                  if files
                    svncmd += files
                  end
                  puts "#{PREFIX} #{svncmd.join(' ')}"
                  _pid = Process.spawn(*svncmd, out: w, err: [:child, :out])
                  w.close

                  _pid, status = Process.wait2
                  outerr = r.read
                  r.close

                  if status.success?
                    break
                  end
                rescue StandardError => e
                  outerr = e.inspect
                  break
                end
              end

              puts outerr # show what happened last
             end # lockfile
            } # chdir
          else # directory does not exist
            # Don't bother locking here -- it should be very rarely needed
            system!('svn', 'checkout', "--depth=#{depth}", svnpath, name)
            if files
              system!('svn', 'update', *files, {chdir: name})
            end
          end
          # check that explicitly required files exist
          files&.each do |file|
            path = File.join(name, file)
            puts "Missing: #{path}" unless File.exist? path
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
            hash, err = ASF::SVN.getInfoAsHash(name)
            if hash
              urlact = hash['URL']
              urlexp = description['url']
              unless urlact.end_with? urlexp # urlexp is relative only
                puts "URL: #{urlact} expected to end with #{urlexp}"
                errors += 1
              end
              depthact = hash['Depth'] || 'infinity'
              depthexp = description['depth'] || 'infinity'
              unless depthact == depthexp
                puts "Depth: #{depthact} expected to be #{depthexp}"
                errors += 1
              end
            else
              puts "Error getting details for #{name}: #{err}"
              errors += 1
            end
          else
            puts "Directory not found - expecting checkout of #{ASF::SVN.svnpath!(name)}"
            errors += 1
          end
        end
      end
      puts
      if errors > 0
        puts "** Found #{errors} error(s) **"
      else
        puts '** No errors found **'
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
      mkdir_p? File.dirname(git)
      Dir.chdir File.dirname(git) do
        require 'uri'
        base = URI.parse('git://git.apache.org/')
        gitrepos.each do |name, description|
          unless description
            puts "Skipping git:pull of #{name} because no details were found"
            next
          end
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
              system!('git', 'checkout', branch) if branch
              system!('git', 'fetch', 'origin')
              system!('git', 'reset', '--hard', "origin/#{branch || 'master'}")
            end
          else
            depth = description['depth']

            # fresh checkout
            if depth
              system!('git', 'clone', '--depth', depth.to_s, (base + description['url']).to_s, name)
            else
              system!('git', 'clone', (base + description['url']).to_s, name)
            end
            system!('git', 'checkout', branch, {chdir: name}) if branch
          end
        end
      end
    end
  end
end

# update documentation
task :rdoc => 'www/docs/api/index.html'
file 'www/docs/api/index.html' => Rake::FileList['lib/whimsy/**/*.rb'] do
  # remove old files first
  FileUtils.remove_dir(File.join(File.dirname(__FILE__),'www/docs/api'), true) # ignore error if missing
  system!('rdoc', 'lib/whimsy', '--output', 'www/docs/api', '--force-output',
    '--title', 'whimsy/asf lib', {chdir: File.dirname(__FILE__)})
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

# Temporary files used to propagate settings into container
LDAP_HTTPD_PATH = '../.ldap_httpd.tmp'
LDAP_WHIMSY_PATH = '../.ldap_whimsy.tmp'

# Allow use of security database on macOS
# Keychain needs to be set up with an application password
# with the Account value of the user_dn
def getpass(user_dn)
  pw = $stdin.getpass("password for #{user_dn}: ")
  return pw unless pw == '*'
  if RbConfig::CONFIG['host_os'].start_with? 'darwin'
    pw, status = Open3.capture2('security', 'find-generic-password', '-a', user_dn, '-w')
    raise "ERROR: problem running security: #{status}" unless status.success?
  else
    raise "ERROR: sorry, don't know how to get password from secure storage"
  end
  return pw.strip
end

def ldap_init
  $LOAD_PATH.unshift 'lib'
  require 'io/console' # cannot prompt from container, so need to do this upfront
  require 'whimsy/asf/config'

  whimsy_dn = ASF::Config.get(:whimsy_dn) or raise 'ERROR: Must provide whimsy_dn value in .whimsy'
  whimsy_pw = getpass(whimsy_dn)
  raise 'ERROR: Password is required' unless whimsy_pw.size > 1

  httpd_dn = ASF::Config.get(:httpd_dn)
  if httpd_dn
    httpd_pw = getpass(httpd_dn)
    raise 'ERROR: Password is required' unless httpd_pw.size > 1
  else # default to whimsy credentials
    httpd_dn = whimsy_dn
    httpd_pw = whimsy_pw
  end
  File.open(LDAP_HTTPD_PATH, 'w', 0o600) do |w|
    w.puts httpd_dn
    w.puts httpd_pw
  end
  File.open(LDAP_WHIMSY_PATH, 'w', 0o600) do |w|
    w.puts whimsy_dn
    w.puts whimsy_pw
  end
end

# Process template files replacing variable references
def filter(src, dst, ldaphosts, ldapbinddn, ldapbindpw)
  require 'erb'
  template = ERB.new(File.read(src))
  File.open(dst, 'w') do |w|
    w.write(template.result(binding))
  end
end

# Set up LDAP items in container context
def ldap_setup
  # Link to file in running container
  FileUtils.cp LDAP_WHIMSY_PATH, '/tmp/ldap.tmp'
  FileUtils.rm_f LDAP_WHIMSY_PATH # remove work file
  FileUtils.chown 'www-data', 'www-data', '/tmp/ldap.tmp'
  ln_sf '/tmp/ldap.tmp', '/srv/ldap.txt'

  ldapbinddn = ldapbindpw = nil
  File.open(LDAP_HTTPD_PATH, 'r') do |r|
    ldapbinddn = r.readline.strip
    ldapbindpw = r.readline.strip
  end
  FileUtils.rm_f LDAP_HTTPD_PATH # remove work file

  $LOAD_PATH.unshift 'lib'
  require 'whimsy/asf/config'
  hosts = ASF::Config.get(:ldap)
  raise 'ERROR: Must define :ldap in ../.whimsy' unless hosts

  ldaphosts = hosts.join(' ').gsub('ldaps://', '')

  filter('docker-config/whimsy.conf',
    '/etc/apache2/sites-enabled/000-default.conf', ldaphosts, ldapbinddn, ldapbindpw)
  filter('docker-config/25-authz_ldap_group_membership.conf',
    '/etc/apache2/conf-enabled/25-authz_ldap_group_membership.conf', ldaphosts, ldapbinddn, ldapbindpw)
  # Add the URI and BASE for use by ldapsearch from shell
  File.open("/etc/ldap/ldap.conf",'a+') do |f|
    f.puts "URI #{hosts.join(' ')}"
    f.puts "BASE dc=apache,dc=org"
  end
end

# Docker support
namespace :docker do
  task :build do
    sh "docker compose build #{SERVICE}"
  end

  task :update => :build do
    sh 'docker compose run  --entrypoint ' +
      %('bash -c "rake update"') +
      " #{SERVICE}"
  end

  task :up do
    ldap_init # create LDAP config data files
    # Start the container which then runs 'rake docker:entrypoint'
    sh 'docker compose up'
  end

  task :exec do
    sh "docker compose exec #{SERVICE} /bin/bash"
  end

  task :bash do
    sh "docker compose run --rm  --entrypoint /bin/bash #{SERVICE}"
  end

  # cannot depend on :config
  # It runs in container, and needs to occur first
  task :scaffold do

    # This should already exist, but just in case
    mkdir_p? '/srv/whimsy/www/members'

    unless File.exist? '/srv/whimsy/www/members/log'
      ln_s '/var/log/apache2', '/srv/whimsy/www/members/log'
    end

    begin
      mode = File.stat('/var/log/apache2').mode
      if mode & 7 != 5
        chmod 0o755, '/var/log/apache2'
      end
      # ensure log files are readable
      sh 'chmod 0644 /var/log/apache2/*.log'
    rescue StandardError => e
      puts e.inspect
    end

    # Create other needed directories
    mkdir_p? '/srv/cache'
    mkdir_p? '/srv/mail/secretary'
    # The list-* files are pushed from the mailing list server to the live Whimsy
    # ensure there are empty files here
    mkdir_p? '/srv/subscriptions'
    Dir.chdir '/srv/subscriptions' do
      # start is done first by the server
      %w{start allows counts denys digests flags mods sendsubscribertomods subs}.each do |suffix|
        file = "list-#{suffix}"
        FileUtils.touch file unless File.exist? file
      end
    end
    # in case
    mkdir_p? '/srv/whimsy/www/docs/api'
    # there may be more

    # add support for CLI use
    unless File.exist? '/root/.bash_aliases'
      ln_s '/srv/.bash_aliases', '/root/.bash_aliases'
    end

    # Allow logs to be written to host system
    if Dir.exist? '/srv/apache2_logs'
      FileUtils.rm_rf '/var/log/apache2'
      ln_s '/srv/apache2_logs', '/var/log/apache2'
    end

    ldap_setup # set up LDAP entries in container
  end

  # This is the entrypoint in the Dockerfile so runs in the container
  task :entrypoint => [:scaffold] do
    sh 'apache2ctl -DFOREGROUND'
  end
end
