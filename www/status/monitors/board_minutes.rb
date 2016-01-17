#
# Monitor status of board minutes
#

def Monitor.board_minutes(previous_status)
  index = File.expand_path('../../www/board/minutes/index.html')
  log = File.expand_path('../../www/logs/collate_minutes')

  if File.read(log) =~ /\*\*\* (Exception.*) \*\*\*/
    {level: 'danger', data: $1}
  else
    "Last updated: #{File.mtime(index)}"
  end
end
