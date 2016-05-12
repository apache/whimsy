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
require 'thread'
require 'fileutils'

# extract script name
script = File.basename(__FILE__, '.rb')

#
### option parsing
#

options = OpenStruct.new
options.remote = 'https://git-dual.apache.org/repos/asf/whimsy.git'
options.local = '/srv/whimsy'
options.pidfile = "/var/run/#{script}.pid"
options.streamURL = 'http://gitpubsub-wip.apache.org:2069/json/*'
# options.streamURL = 'http://svn.apache.org:2069/commits'

optionparser = OptionParser.new do |opts|
  opts.on '-u', '--user id', "Optional user to run #{script} as" do |user|
    options.user = user
  end

  opts.on '-g', '--group id', "Optional group to run #{script} as" do |group|
    options.group = group
  end

  opts.on '-p', '--pidfile path', "Optional pid file location" do |path|
    options.pidfile = path
  end

  opts.on '-d', '--daemonize', "Run as daemon" do
    options.daemonize = true
  end

  opts.on '-s', '--stream', "StreamURL" do |url|
    options.streamURL = url
  end

  opts.on '-r', '--remote', "Git Clone URL" do |url|
    options.streamURL = url
  end

  opts.on '-c', '--clone', "Git Clone Directory" do |path|
    options.local = path
  end

  opts.on '--stop', "Kill the currently running #{script} process" do
    options.kill = true
  end
end

optionparser.parse!

#
### process management
#

# Either kill old process, or start a new one
if options.kill
  if File.exists? options.pidfile
    Process.kill 'TERM', File.read(options.pidfile).to_i
    File.delete options.pidfile if File.exists? options.pidfile
    exit 0
  end
else
  # optionally daemonize
  Process.daemon if options.daemonize

  # PID file management
  if File.writable? options.pidfile
    File.write options.pidfile, Process.pid.to_s
    at_exit { File.delete options.pidfile if File.exists? options.pidfile }
  else
    STDERR.puts "EACCES: Skipping creation of pidfile #{options.pidfile}"
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
  system "git clone #{options.remote} #{options.local}"
end

#
# Monitor PubSub endpoint (see http://www.apache.org/dev/gitpubsub.html)
#

# prime the pump
restartable = false
notification_queue = Queue.new
notification_queue.push 'commit' => {'project' => 'whimsy'}

ps_thread = Thread.new do
  begin
    uri = URI.parse(options.streamURL)

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri

      http.request request do |response|
        body = ''
        response.read_body do |chunk|
          if chunk =~ /\r\n$|\0$/
            notification = JSON.parse(body + chunk.chomp("\0"))
            body = ''

            if notification['stillalive']
              restartable = true
            elsif notification['commit']
              notification_queue << notification
            elsif notification['svnpubsub']
              next
            else
              STDERR.puts '*** unexpected notification ***'
              STDERR.puts notification.inspect
            end
          else
            body += chunk
          end
        end
      end
    end
  rescue Errno::ECONNREFUSED => e
    restartable = true
    STDERR.puts e
    sleep 3
  rescue Exception => e
    STDERR.puts e
    STDERR.puts e.backtrace
  end
end

#
# Process queued requests
#
project = File.basename(options.remote, '.git')

begin
  while ps_thread.alive?
    notification = notification_queue.pop
    next unless notification['commit']['project'] == project
    notification_queue.clear
    Dir.chdir(options.local) do
      before = `git log --oneline -1`
      system 'git fetch origin'
      system 'git clean -df'
      system 'git reset --hard origin/master'
      if File.exist? 'Rakefile' and `git log --oneline -1` != before
        system 'rake update'
      end
    end
  end
rescue SignalException => e
  STDERR.puts e
  restartable = false 
rescue Exception => e
  if ps_thread.alive?
    STDERR.puts e
    STDERR.puts e.backtrace
    restartable = false 
  end
end

#
# restart
#

if restartable
  STDERR.puts 'restarting'

  # reconstruct path to Ruby executable
  require 'rbconfig'
  ruby = File.join(
    RbConfig::CONFIG["bindir"],
    RbConfig::CONFIG["ruby_install_name"] + RbConfig::CONFIG["EXEEXT"]
  )

  # relaunch script after a one second delay
  sleep 1
  exec ruby, __FILE__, *ARGV 
end
