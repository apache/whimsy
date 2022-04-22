#
# Monitor status of public json directory
#

=begin

Checks log files with names 'public-*' for relevant output.

Possible status level output:
Success - only DEBUG or INFO messages seen
Info - diff -u output detected
Warning - WARN log messages seen or file more than 1.5 hours old
Danger - File more than 24 hours old or Exception while processing

=end

require 'fileutils'
require 'time'

def Monitor.public_json(previous_status)
  danger_period = 86_400 # one day

  warning_period = 5400 # 1.5 hours

  logdir = File.expand_path('../../www/logs')
  logs = File.join(logdir, 'public-*')

  archive = File.join(logdir,'archive')
  FileUtils.mkdir(archive) unless File.directory?(archive)

  status = {}

  Dir[logs].each do |log|
    name = File.basename(log).sub('public-', '').to_sym

    begin
      status[name] = {
        href: "../logs/#{File.basename(log)}",
        mtime: File.mtime(log).gmtime.iso8601, # to agree with normalise
        level: 'success' # to agree with normalise
      }
      contents = File.read(log, encoding: Encoding::UTF_8)
      contents_save = contents.dup # in case we need to send an email

      # Ignore Wunderbar logging for normal messages (may occur multiple times)
      contents.gsub!(/^(_INFO|_DEBUG) .*?\n+/, '')

      # diff -u output: (may have additional \n at end)
      if contents.gsub!(/^--- .*?\n\n?(\n|\Z)/m, '')
        status[name].merge! level: 'info', title: 'updated'
      end

      # Wunderbar warning
      warnings = contents.scan(/^_WARN (.*?)\n+/)
      if warnings.length == 1
        contents.sub!(/^_WARN (.*?)\n+/, '')
        status[name].merge! level: 'warning', data: $1
      elsif warnings.length > 0
        contents.gsub!(/^_WARN (.*?)\n+/, '')
        status[name].merge! level: 'warning', data: warnings.flatten,
          title: "#{warnings.length} warnings"
      end

      # Ruby warnings
      if contents.gsub!(%r{^/(?:var|usr)/lib/\S+: (warning:.*?)\n+}, '')
        status[name].merge! level: 'warning', data: $1
      end

      # Check to see if the log has been updated recently
      if Time.now - File.mtime(log) > warning_period
        status[name].merge! level: 'warning',
          data: "Last updated: #{File.mtime(log).to_s} (more than 1.5 hours old)"
      end

      # Check to see if the log has been updated recently
      if Time.now - File.mtime(log) > danger_period
        status[name].merge! level: 'danger',
          data: "Last updated: #{File.mtime(log).to_s} (more than 24 hours old)"
      end

      # Treat everything left as an error to be reported
      unless contents.empty?
        status[name].merge! level: 'danger', data: contents.split("\n")
      end
      # monitor.rb ignores data if title is set
      # TODO: is this a bug in monitor.rb ?
      if status[name][:data]
        status[name].delete_if { |k, v| k.eql? :title}
      end

      # Has there been a change since the last check?
      if previous_status[:data] and status[name] != previous_status[:data][name]
        lvl = status[name][:level]
        #      $stderr.puts "Status has changed for #{name} #{lvl}"
        if lvl and lvl != 'info' and lvl != 'success' # was there a problem?
          # Save a copy of the log; append the severity so can track more problems
          file = File.basename(log)
          FileUtils.copy log, File.join(archive, file + '.' + lvl), preserve: true
          begin
            require 'mail'
            $LOAD_PATH.unshift '/srv/whimsy/lib'
            require 'whimsy/asf'
            ASF::Mail.configure
            mail = Mail.new do
              from 'Public JSON job monitor  <dev@whimsical.apache.org>'
              to 'Notification List <notifications@whimsical.apache.org>'
              subject "Problem (#{lvl}) detected in #{name} job"
              body "\nLOG:\n#{contents_save}\nSTATUS: #{status[name]}\n"
            end
            # in spite of what the docs say, this does not seem to work in the body above
            mail.charset = 'utf-8'
            # Replace .mail suffix with more accurate one
            mail.message_id = "<#{Mail.random_tag}@#{::Socket.gethostname}.apache.org>"
            # deliver mail
            mail.deliver!
          rescue => e
            $stderr.puts "Send mail failed: exception #{e}" # record error in server log
          end
        end
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

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('public_json') # must agree with method name above
end
