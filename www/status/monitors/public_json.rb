#
# Monitor status of public json directory
#

def Monitor.public_json(previous_status)
  danger_period = 86_400 # one day

  warning_period = 5400 # 1.5 hours

  logs = File.expand_path('../../www/logs/public-*')

  status = {}

  Dir[logs].each do |log|
    begin
      name = File.basename(log).sub('public-', '')

      status[name] = {
        href: "../logs/#{File.basename(log)}",
        mtime: File.mtime(log)
      }

      contents = File.read(log, encoding: Encoding::UTF_8)

      # Ignore Wunderbar logging for normal messages (may occur multiple times)
      contents.gsub! /^(_INFO|_DEBUG) .*?\n+/, ''

      # diff -u output:
      if contents.sub! /^--- .*?\n(\n|\Z)/m, ''
        status[name].merge! level: 'info', title: 'updated'
      end

      # Wunderbar warning
      warnings = contents.scan(/^_WARN (.*?)\n+/)
      if warnings.length == 1
        contents.sub! /^_WARN (.*?)\n+/, ''
        status[name].merge! level: 'warning', data: $1
      elsif warnings.length > 0
        contents.gsub! /^_WARN (.*?)\n+/, ''
        status[name].merge! level: 'warning', data: warnings.flatten,
          title: "#{warnings.length} warnings"
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
