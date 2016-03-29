#
# Monitor status of secretarial mail
#

def Monitor.secmail(previous_status)
  log = '/srv/mail/procmail.log'

  {mtime: File.mtime(log)}
end

# for debugging purposes
if __FILE__ == $0
  puts Monitor.secmail(nil)
end
