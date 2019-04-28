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

# send summary email to committers

# fetch minutes
@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = File.join(AGENDA_WORK, "#{@minutes.sub('.txt', '.yml')}")
minutes_file.untaint if @minutes =~ /^board_minutes_\d+_\d+_\d+\.txt$/

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

# ensure headers have proper CRLF
header, body = @text.untaint.split(/\r?\n\r?\n/, 2)
header.gsub! /\r?\n/, "\r\n"

# send mail
ASF::Mail.configure
mail = Mail.new("#{header}\r\n\r\n#{body}")
mail.deliver!

# update todos
minutes[:todos] ||= {}
minutes[:todos][:summary_sent] ||= true
File.write minutes_file, YAML.dump(minutes)

# return response
{mail: mail.to_s, minutes: minutes}
