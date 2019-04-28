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
