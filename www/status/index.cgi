#!/usr/bin/ruby
require 'json'
require 'time'

json = File.expand_path('../status.json', __FILE__)
status = JSON.parse(File.read(json)) rescue {}

# Get new status every minute
if not status['mtime'] or Time.now - Time.parse(status['mtime']) > 60
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
if %w(success info).include? status['level']
  print "Status: 200 OK\r\n\r\n"
else
  print "Status: 400 #{status['title'] || 'failure'}\r\n\r\n"
end

# What the browser sees:
print <<-EOF
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8"/>
    <title>Whimsy-Test Status</title>
    
    <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css"/>
    <link rel="stylesheet" type="text/css" href="css/status.css"/>
    
    <script type="text/javascript" src="js/jquery.min.js"></script>
    <script type="text/javascript" src="js/bootstrap.min.js"></script>
    <script type="text/javascript" src="js/status.js"></script>
  </head>

  <body>
    <img src="../whimsy.svg" class="logo"/>
    <h1>Whimsy-Test Status</h1>

    <div class="list-group list-group-root well">
      Loading...
    </div>

    <p>
      This status is monitored by:
      <a href="https://www.pingmybox.com/dashboard?location=470">Ping My
      Box</a>.
    </p>
  </body>
</html>
EOF
