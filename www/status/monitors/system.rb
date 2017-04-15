#
# Monitor status of system
# Currently only checks puppet
#

require 'time'

def Monitor.system(previous_status)
  name=:puppet
  status = {}
  status[name] = {
    command: 'service puppet status',
  }

  begin
    ENV['LC_ALL'] = 'en_US.UTF-8'
    ENV['LANG'] = 'en_US.UTF-8'
    ENV['LANGUAGE'] = 'en_US.UTF-8'

    puppet = `service puppet status`.force_encoding('utf-8').strip

    if puppet.include? 'Active: active (running)'
      status[name].merge! level: 'success', data: puppet
    elsif puppet.include? '* agent is running'
      status[name].merge! level: 'success', data: puppet
    else
      status[name].merge! level: 'warning', data: puppet
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
