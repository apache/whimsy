#
# Monitor status of board minutes
#

def Monitor.board_minutes(previous_status)
  index = File.expand_path('../../www/board/minutes/index.html')
  log = File.read(File.expand_path('../../www/logs/collate_minutes'))

  if log =~ /\*\*\* (Exception.*) \*\*\*/
    {
      level: 'danger',
      data: $1,
      href: '../logs/collate_minutes'
    }
  elsif log.length > 0
    {
      level: 'info',
      data: "Last updated: #{File.mtime(index)}",
      href: '../logs/collate_minutes'
    }
  else
    {mtime: File.mtime(index)}
  end
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('board_minutes') # must agree with method name above
end