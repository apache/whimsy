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
# convert attachment to pdf
#

message = Mailbox.find(@message)

begin
  source = message.find(@selected).as_pdf
  source.rewind

  name = @selected.sub(/\.\w+$/, '') + '.pdf'

  # If output file is empty, then the command failed
  raise "Failed to pdf-ize #{@selected} in #{@message}" unless File.size? source.path

  message.update_attachment @selected, content: source.read, name: name,
    mime: 'application/pdf'

ensure
  source.unlink if source
end

{attachments: message.attachments, selected: name}
