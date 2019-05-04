##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#
# Monitor status of board minutes
#

=begin
The code checks the collate_minutes log file and the file
    www/board/minutes/index.html

Possible status level responses:
Danger - log contains an Exception message
Info - Log contains some other content
Success - Log is present, but empty
Fatal - log or index are not present/readable (status level is generated by caller)

=end

require 'time'

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
    {mtime: File.mtime(index).gmtime.iso8601, level: 'success'} # to agree with normalise
  end
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('board_minutes') # must agree with method name above
end