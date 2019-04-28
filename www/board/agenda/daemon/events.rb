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

require 'fileutils'
require 'json'
require 'securerandom'

require 'whimsy/asf/config'

#
# Low-tech, file based event manager.  Each message is stored as a separate
# file on disk, and is deleted once processed.
#
# No direct use of timers, events, or threads are made allowing this
# service to be used in a variety of contexts (e.g. Sinatra and 
# EventMachine).
#

class Events
  if ENV['RACK_ENV'] == 'test'
    AGENDA_WORK = File.expand_path('test/work/data').untaint
  else
    AGENDA_WORK = ASF::Config.get(:agenda_work).untaint || '/srv/agenda'
  end

  WORKDIR = File.expand_path('events', AGENDA_WORK)

  # capture a message to be sent
  def self.post(message)
    FileUtils.mkdir_p WORKDIR
    filename = SecureRandom.hex(16)
    File.write(File.join(WORKDIR, filename), JSON.generate(message))
    message
  end

  # process pending messages
  def self.process()
    Dir[File.join(WORKDIR, '*')].each do |file|
      begin
        message = JSON.parse(File.read(file))
        if message[:private]
          Channel.post_private(message[:private], message)
        else
          Channel.post_all(message)
        end
      ensure
        File.unlink file
      end
    end
  end
end
