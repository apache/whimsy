#
# Whimsy pubsub support: watches for updates to the whimsy repository,
# fetches the changes and deploys them.
#
# For usage instructions, try
#
#   ruby pubsub.rb --help
#

require 'optparse'
require 'ostruct'
require 'etc'
require 'net/http'
require 'json'
require 'fileutils'

def stamp(*s)
  line = caller[0].split(':')[1]
  '%s: @%s %s' % [Time.now.gmtime.to_s, line, s.join(' ')]
end

# extract script name
script = File.basename(__FILE__, '.rb')

#
### option parsing
#

options = OpenStruct.new
options.remote = 'https://gitbox.apache.org/repos/asf/whimsy.git'
options.local = '/srv/whimsy'
options.pidfile = "/var/run/#{script}.pid"
options.streamURL = 'http://pubsub.apache.org:2069/git/'
options.puppet = false

optionparser = OptionParser.new do |opts|
  opts.on '-u', '--user id', "Optional user to run #{script} as" do |user|
    options.user = user
  end

  opts.on '-g', '--group id', "Optional group to run #{script} as" do |group|
    options.group = group
  end

  opts.on '-p', '--pidfile path', 'Optional pid file location' do |path|
    options.pidfile = path
  end

  opts.on '-d', '--daemonize', 'Run as daemon' do
    options.daemonize = true
  end

  opts.on '--puppet', 'Use puppet agent to update' do
    options.puppet = true
  end

  opts.on '-s', '--stream', 'StreamURL' do |url|
    options.streamURL = url
  end

  opts.on '-r', '--remote', 'Git Clone URL' do |url|
    options.streamURL = url
  end

  opts.on '-c', '--clone', 'Git Clone Directory' do |path|
    options.local = path
  end

  opts.on '--stop', "Kill the currently running #{script} process" do
    options.kill = true
  end
end

optionparser.parse!

# Check for required tools

if options.puppet and `which puppet 2>/dev/null`.empty?
  STDERR.puts 'puppet not found in path; exiting'
  exit 1
end

%w(git rake).each do |tool|
  if `which #{tool} 2>/dev/null`.empty?
    STDERR.puts "#{tool} not found in path; exiting"
    exit 1
  end
end

#
### process management
#

# Either kill old process, or start a new one
if options.kill
  if File.exist? options.pidfile
    Process.kill 'TERM', File.read(options.pidfile).to_i
    File.delete options.pidfile if File.exist? options.pidfile
    exit 0
  end
else
  # optionally daemonize
  Process.daemon if options.daemonize

  # Determine if pidfile is writable
  if File.exist? options.pidfile
    writable = File.writable? options.pidfile
  else
    writable = File.writable? File.dirname(options.pidfile)
  end

  # PID file management
  if writable
    File.write options.pidfile, Process.pid.to_s
    at_exit { File.delete options.pidfile if File.exist? options.pidfile }
  else
    STDERR.puts stamp "EACCES: Skipping creation of pidfile #{options.pidfile}"
  end
end

# Optionally change user/group
if Process.uid == 0
  Process::Sys.setgid Etc.getgrnam(options.group).gid if options.group
  Process::Sys.setuid Etc.getpwnam(options.user).uid if options.user
end

# Perform initial clone
if not Dir.exist? options.local
  FileUtils.mkdir_p File.basename(options.local)
  system('git', 'clone', options.remote, options.local)
end

#
# Monitor PubSub endpoint (see https://infra.apache.org/pypubsub.html)
#

PROJECT = File.basename(options.remote, '.git')

ALIVE = File.join('/tmp', "#{File.basename(__FILE__)}.alive") # Help detect failures

# prime the pump
restartable = false
notification_queue = Queue.new
notification_queue.push 'project' => PROJECT

ps_thread = Thread.new do
  begin
    uri = URI.parse(options.streamURL)

    Net::HTTP.start(uri.host, uri.port, :open_timeout => 30) do |http|
      request = Net::HTTP::Get.new uri.request_uri

      http.request request do |response|
        body = ''
        response.read_body do |chunk|
          # Looks like the service only sends \n terminators now
          if chunk =~ /\r?\n$|\0$/
            notification = JSON.parse(body + chunk.chomp("\0"))
            body = ''

            FileUtils.touch(ALIVE)
            if notification['stillalive']
              restartable = true
            elsif notification['push']
              notification_queue << notification['push']
            elsif notification['commit']
              notification_queue << notification['commit']
            elsif notification['svnpubsub']
              next
            else
              STDERR.puts stamp '*** unexpected notification ***'
              STDERR.puts stamp notification.inspect
            end
          else
            body += chunk
          end
        end
      end
    end
  rescue Errno::ECONNREFUSED => e
    restartable = true
    STDERR.puts stamp e
    sleep 3
  rescue Exception => e
    STDERR.puts stamp e
    STDERR.puts stamp e.backtrace
  end
  puts stamp 'Thread ended'
end

#
# Process queued requests
#

begin
  mtime = File.mtime(__FILE__)
  while ps_thread.alive?
    notification = notification_queue.pop
    next unless notification['project'] == PROJECT
    puts stamp 'Detected notification for our project'
    notification_queue.clear

    if options.puppet
      # puppet agent -t has the following exit codes:
      # 0: The run succeeded with no changes or failures; the system was already in the desired state.
      # 1: The run failed, or wasn´t attempted due to another run already in progress.
      # 2: The run succeeded, and some resources were changed.
      # 4: The run succeeded, and some resources failed.
      # 6: The run succeeded, and included both changes and failures.
      # Only attempt a restart if the run failed entirely
      #
      # Update using puppet.  If puppet fails, it may be due to puppet already
      # running; in which case it may not have picked up this update.  So try
      # again in 30, 60, 90, and 120 seconds, for a total of five minutes.
      4.times do |i|
        puts stamp "Starting Puppet"
        system('puppet', 'agent', '-t')
        status = $?.exitstatus
        puts stamp "Puppet completed with status #{status}"
        break unless status == 1
        puts stamp "Failed to run Puppet, will try again shortly"
        sleep 30 * (i+1)
      end
    else
      puts stamp 'Update git in foreground'
      # update git directories in the foreground
      Dir.chdir(options.local) do
        before = `git log --oneline -1`
        system('git', 'fetch', 'origin')
        system('git', 'clean', '-df')
        system('git', 'reset', '--hard', 'origin/master')
        if File.exist? 'Rakefile' and `git log --oneline -1` != before
          system('rake', 'update')
        end
      end
    end
    if mtime != File.mtime(__FILE__) # we have been updated
      puts stamp 'Detected self update'
      break
    end
  end
  puts stamp 'Queue processing ended'
rescue SignalException => e
  STDERR.puts stamp e.inspect
  restartable = false
rescue Exception => e
  STDERR.puts stamp e
  STDERR.puts stamp e.backtrace
  if ps_thread.alive?
    restartable = false # why?
  end
end

#
# restart
#

if restartable
  STDERR.puts stamp 'restarting'

  # relaunch script after a one second delay
  sleep 1
  exec RbConfig.ruby, __FILE__, *ARGV
else
  STDERR.puts stamp 'not restartable'
end
