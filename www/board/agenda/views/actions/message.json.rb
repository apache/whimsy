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
# chat message received from the client
#

@type ||= :chat

log = {type: @type, user: env.user, text: @text, timestamp: Time.now.to_f*1000}

log[:link] = @link if @link

if @text.start_with? '/me '
  log[:text].sub! /^\/me\s+/, '*** '
  log[:type] = :info
elsif @type == :chat
  chat = "#{AGENDA_WORK}/#{@agenda.sub('.txt', '')}-chat.yml"
  File.write(chat, YAML.dump([])) if not File.exist? chat

  File.open(chat, 'r+') do |file|
    file.flock(File::LOCK_EX)
    data = YAML.load(file.read)
    file.rewind
    data << log
    file.write YAML.dump(data)
  end
end

Events.post log.merge(agenda: @agenda)
