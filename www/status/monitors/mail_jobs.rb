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
# Monitor status of /srv/subscription directory
#

=begin

Checks /srv/subscription files for fresheness

Possible status level output:
Success - File up to date
Warning - File more than 1 + cron hours old
Danger - File more than 24 hours old or Exception while processing

=end

require 'fileutils'
require 'time'

def Monitor.mail_jobs(previous_status)
  danger_period = 86_400 # one day


  logdir = '/srv/subscriptions'
  logs = File.join(logdir, '*')

  status = {}

  Dir[logs].each do |log|
    name = File.basename(log).to_sym
    next unless name == :'list-start' # only list-start is now guaranteed to be updated (hourly)

    begin
      warning_hours = 2
      warning_period = warning_hours * 3600

      status[name] = {
        mtime: File.mtime(log).gmtime.iso8601, # to agree with normalise
        level: 'success' # to agree with normalise
      }

      # Check to see if the log has been updated recently
      if Time.now - File.mtime(log) > warning_period
        status[name].merge! level: 'warning',
          data: "Last updated: #{File.mtime(log).to_s} (more than #{warning_hours} hours old)"
      end

      # Check to see if the log has been updated recently
      if Time.now - File.mtime(log) > danger_period
        status[name].merge! level: 'danger',
          data: "Last updated: #{File.mtime(log).to_s} (more than 24 hours old)"
      end

      # monitor.rb ignores data if title is set
      # TODO: is this a bug in monitor.rb ?
      if status[name][:data]
        status[name].delete_if { |k, v| k.eql? :title}
      end

    rescue Exception => e
      status[name] = {
        level: 'danger',
        data: {
          exception: {
            level: 'danger',
            text: e.inspect,
            data: e.backtrace
          }
        }
      }
    end
  end

  {data: status}
end

private

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('mail_jobs') # must agree with method name above
end
