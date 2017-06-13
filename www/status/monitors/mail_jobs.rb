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
    next if name == :'incubator-mods' # obsolete

    begin
      warning_hours = get_hours(name)
      warning_period = warning_hours * 3600

      status[name] = {
        href: "../logs/#{File.basename(log)}",
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

def get_hours(name)
  job_hours = { # how often the jobs run
    board:   1,
    members: 1,
  }
  job_hours.default = 6
  job_hours[name] + 1
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('mail_jobs') # must agree with method name above
end
