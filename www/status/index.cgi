#!/usr/bin/env ruby
require 'json'
require 'time'

json = File.expand_path('../status.json', __FILE__)
status = JSON.parse(File.read(json)) rescue {}

# Get new status every minute
if not status[:mtime] or Time.now - Time.parse(status[:mtime]) > 60
  begin
    require_relative './monitor'
    status = Monitor.new.status || {}
  rescue Exception => e
    print "Status: 500 Internal Server Error\r\n"
    print "Context-Type: text/plain\r\n\r\n"
    puts e.to_s
    puts "\nbacktrace:"
    e.backtrace.each {|line| puts "  #{line}"}
    exit
  end
end

# The following is what infrastructure team sees:
if %w(success info warning).include? status[:level]
  summary_status = "200 OK"
else
  summary_status = "400 #{status[:title] || 'failure'}"
end
print "Status: #{summary_status}\r\n\r\n"

git_info = `git show --format="%h  %ci %cr"  -s HEAD`.strip rescue "?"
# TODO better format; don't assume we use master
git_repo = `git ls-remote origin master`.strip rescue "?"

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
      <li><a href="svn">Subversion</a></li>
      <li>Git code info: #{git_info}</li>
      <li>Git repo info: #{git_repo}</li>
    </ul>
  </body>
</html>
EOF
