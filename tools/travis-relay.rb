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
# forward travis notifications to notifications@whimsical.
#
# 'To' header will be replaced
# 'From' header will effectively be replaced
# Transport and return path headers names will be prepended with 'X-'
# Original content headers will be dropped (and recreated).
#

munge = %w(received delivered-to return-path)
skip = %w(content-type content-transfer-encoding)

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'mail'
require 'whimsy/asf'

ASF::Mail.configure

original = Mail.new(STDIN.read.encode(crlf_newline: true))
exit unless original.from.include? "builds@travis-ci.org"

copy = Mail.new

# copy/munge/skip headers
original.header.fields.each do |field|
  name = field.name
  next if skip.include? name.downcase
  name = "X-#{name}" if munge.include? name.downcase

  if name.downcase == 'to'
    copy.header['To'] = '<notifications@whimsical.apache.org>'
  else
    copy.header[name] = field.value
  end
end

# copy content
copy.text_part = original.text_part if original.text_part
copy.html_part = original.html_part if original.html_part

# deliver
copy.deliver!
