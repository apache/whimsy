#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'json'
require 'time'
require 'whimsy/asf/status'

start = $prev = Time.now
$timings1 = [] # more debug timing
timings2 = []

def timediff(what)
  now = Time.now
  $timings1 << [what, now - $prev]
  $prev = now
end

json = File.expand_path('../status.json', __FILE__)
begin
  status = JSON.parse(File.read(json, encoding: Encoding::UTF_8), {symbolize_names: true}) 
rescue Exception => e
  $stderr.puts "index.cgi: Failed to read status.json: #{e}"
  status = {}
end
timediff('parsed')

# Get new status every minute
if not status[:mtime] or Time.now - Time.parse(status[:mtime]) > 60
  begin
    require_relative './monitor'
    t1a = Time.now
    sm = StatusMonitor.new
    t1b = Time.now
    status = sm.status || {}
    t1c = Time.now
    timings2 = sm.timings || []
    t1d = Time.now
  rescue Exception => e
    print "Status: 500 Internal Server Error\r\n"
    print "Context-Type: text/plain\r\n\r\n"
    puts e.to_s
    puts "\nbacktrace:"
    e.backtrace.each {|line| puts "  #{line}"}
    exit
  end
  timediff('reparsed')
end

# The following is what infrastructure team sees:
if %w(success info warning).include? status[:level]
  summary_status = "200 OK"
else
  summary_status = "400 #{status[:title] || 'failure'}"
  # Log error for later investigation
  $stderr.puts JSON.pretty_generate(status)
end
print "Status: #{summary_status}\r\n\r\n"

git_branch = `git branch --show-current`.strip
git_info = `git show --format="%h  %ci %cr"  -s HEAD`.strip rescue "?"

timediff('git show')

# This is a remote check, so may be delayed
git_repo = `git ls-remote origin #{git_branch}`.strip rescue "?"

timediff('git ls-remote')

hostname = `hostname`

# What the browser sees:
print <<-EOF
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8"/>
    <title>Whimsy Status</title>

    <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css"/>
    <link rel="stylesheet" type="text/css" href="css/status.css"/>

    <script type="text/javascript" src="js/jquery.min.js"></script>
    <script type="text/javascript" src="js/bootstrap.min.js"></script>
    <script type="text/javascript" src="js/status.js"></script>
  </head>

  <body>
    <a href="/">
      <img alt="Whimsy logo" title="Whimsy logo" src="../whimsy.svg" class="logo"/>
    </a>
    <h1>Whimsy Status for #{hostname}</h1>

    <div class="list-group list-group-root well">
      Loading...
    </div>

    <p>
    Overall status: #{summary_status}
    </p>
    <table class="status-legend">
    <tr>
      <td class="alert-success">Success</td>
      <td class="alert-info">Info</td>
      <td class="alert-warning">Warning</td>
      <td class="alert-danger">Danger</td>
      <td class="alert-fatal">Fatal</td>
    </tr>
    </table>
    <br/>

    <p>
      This status is monitored by:
      <a href="https://nodeping.com/reports/status/70MTNEPXE6">NodePing</a>.
      <a href="https://nodeping.com/reports/statusevents/check/2018042000290QH9Q-UMFGNACX">Whimsy(Status)</a>.
      <a href="https://nodeping.com/reports/statusevents/check/2018042000290QH9Q-OZZ2KBZC">Whimsy(Website)</a>.
    </p>

    <h2>Additional status</h2>

    <ul>
      <li><a href="../member/logs">Apache HTTPD error logs</a>
        (ASF member only)</li>
      <li><a href="passenger">Passenger</a> (ASF committer only)</li>
      <li><a href="svn">Subversion</a> (ASF committer only)</li>
      <li>Git code info: #{git_info} (#{git_branch})</li>
      <li>Git repo info: #{git_repo}</li>
    </ul>
  </body>
</html>
EOF

timediff('done') # sets $prev

if $prev - start > 2 # seconds
  $stderr.puts "Times1: #{$timings1} Overall: #{$prev - start}"
  $stderr.puts "Times2: #{timings2}"
end
