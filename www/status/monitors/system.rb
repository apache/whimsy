#
# Monitor status of system
# Currently only checks puppet
#

require 'time'

def Monitor.system(previous_status)
  name='puppet'
  status = {}
  status[name] = {
    mtime: Time.now.gmtime.iso8601,
    command: 'service puppet status'
  }
  begin
    puppet = `service puppet status`.strip
    if puppet.include? ' * agent is running'
      status[name].merge! level: 'warning', title: puppet
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
  {data: status}
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('system') # must agree with method name above
end
