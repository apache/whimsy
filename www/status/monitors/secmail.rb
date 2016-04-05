#
# Monitor status of secretarial mail
#

def Monitor.secmail(previous_status)
  log = '/srv/mail/procmail.log'

  {mtime: File.mtime(log)}
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('secmail') # must agree with method name above
end
