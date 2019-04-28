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
# Process email as it is received
#

Dir.chdir File.dirname(File.expand_path(__FILE__))

require_relative 'models/mailbox'

# read and parse email
STDIN.binmode
email = STDIN.read
hash = Message.hash(email)

fail = nil
begin
  headers = Message.parse(email)
rescue => e
  fail = e
  headers = {
    exception: e.to_s,
    backtrace: e.backtrace[0],
    message: 'See procmail.log for full details'
  }
end

# construct message
month = Time.now.strftime('%Y%m')
mailbox = Mailbox.new(month)
message = Message.new(mailbox, hash, headers, email)

# write message to disk
File.umask(0002)
message.write_headers
message.write_email

# Now fail if there was an error
if fail
  require 'time'
  $stderr.puts "WARNING: #{Time.now.utc.iso8601}: error processing email with hash: #{hash}"
  raise fail
end
