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
# Receive and deliver mail
#

require 'digest'
require 'fileutils'

MAIL_ROOT = '/srv/mail'

# get the message ID
def self.getmid(hdrs)
  mid = hdrs[/^Message-ID:.*/i]
  if mid =~ /^Message-ID:\s*$/i # no mid on the first line
    # capture the next line and join them together
    # line may also start with tab; we don't use \s as this also matches EOL
    # Rescue is in case we don't match properly - we want to return nil in that case
    mid = hdrs[/^Message-ID:.*\r?\n[ \t].*/i].sub(/\r?\n/,'') rescue nil
  end
  mid
end

STDIN.binmode
mail = STDIN.read

# only search headers for MID and List-ID etc
hdrs = mail[/\A(.*?)\r?\n\r?\n/m, 1] || ''

# extract info
dest = hdrs[/^List-Id: <(.*)>/, 1] || hdrs[/^Delivered-To.* (\S+)\s*$/, 1] || 'unknown'
month = Time.now.strftime('%Y%m')
hash = Digest::SHA1.hexdigest(getmid(hdrs) || mail)[0..9]

# build file name
file = "#{MAIL_ROOT}/#{dest[/^[-\w]+/]}/#{month}/#{hash}"

File.umask 0002
FileUtils.mkdir_p File.dirname(file)
File.write file, mail, encoding: Encoding::BINARY
File.chmod 0644, file
