#
# Monitor status of site-scan
#

=begin
The code checks the site-scan log file

Possible status level responses:
Danger - log contains unexpected content
Warning - log hasn't been updated within a day
Info - log is recent and contains only expected content

=end

require 'time'

def Monitor.site_scan(previous_status)
  logdir = File.expand_path('../../www/logs')
  logfile = File.join(logdir, 'site-scan')
  log = File.read(logfile)

  # Drop standard cache info
  log.gsub! /^([-\w]+ )*https?:\S+ \w+\n/, ''
  # Drop other info (must agree with scanner script)
  log.gsub! %r{^(Started|Ended):.+\n}, ''

  danger_period = 86_400 # one day

  if not log.empty?
    # Archive the log file
    require 'fileutils'
    archive = File.join(logdir, 'archive')
    FileUtils.mkdir(archive) unless File.directory?(archive)
    file = File.basename(logfile)
    level = 'danger'
    # remove all non-fatal messages
    level = 'warning' if log.gsub(/(.* error|WARN: timeout scanning.*)\n/, '').empty?
    FileUtils.copy logfile, File.join(archive, file + '.' + level), preserve: true
    {
      level: level,
      data: log.split("\n"),
      href: '../logs/site-scan'
    }
  elsif Time.now - File.mtime(logfile) > danger_period
    {
      level: 'warning',
      data: "Last updated: #{File.mtime(logfile)}",
      href: '../logs/site-scan'
    }
  else
    {mtime: File.mtime(logfile).gmtime.iso8601, level: 'success'}
  end
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('site_scan') # must agree with method name above
end
