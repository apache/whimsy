#
# Monitor status of secretarial mail
#

require 'time'

def Monitor.secmail(previous_status)
  log = '/srv/mail/procmail.log'

{mtime: File.mtime(log).gmtime.iso8601, level: 'success'} # to agree with normalise
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('secmail') # must agree with method name above
end
