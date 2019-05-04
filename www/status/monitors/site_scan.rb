##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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

  log.gsub! /^([-\w]+ )*https?:\S+ \w+\n/, ''

  danger_period = 86_400 # one day

  if not log.empty?
    # Archive the log file
    require 'fileutils'
    archive = File.join(logdir,'archive')
    FileUtils.mkdir(archive) unless File.directory?(archive)
    file = File.basename(logfile)
    FileUtils.copy logfile, File.join(archive, file + '.danger'), preserve: true
    level = 'danger'
    level = 'warning' if log.gsub(/.* error\n/, '').empty?
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
