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

# find indicated mailbox in the list of available mailboxes
available = Dir["#{ARCHIVE}/*.yml"].sort
index = available.find_index "#{ARCHIVE}/#{@mbox}.yml"

# if found, process it
if index
  prevmbox = nil

  if index > 0
    prevmbox = available[index-1].untaint
    prevmbox = nil unless YAML.load_file(prevmbox).any? do |key, mail| 
      mail[:status] != :deleted and not Message.attachments(mail).empty?
    end
  end

  # return previous mailbox name and headers for the messages in the mbox
  {
    mbox: (File.basename(prevmbox, '.yml') if prevmbox),
    messages: Mailbox.new(@mbox).client_headers
  }
end
