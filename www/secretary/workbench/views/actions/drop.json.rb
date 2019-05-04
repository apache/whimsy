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
# drop part of drag and drop
#

message = Mailbox.find(@message)

begin
  source = message.find(@source).as_pdf
  target = message.find(@target).as_pdf

  output = SafeTempFile.new('output') # N.B. this is created as binary

  Kernel.system 'pdfunite', target.path, source.path, output.path

  name = @target.sub(/\.\w+$/, '') + '.pdf'

  # If output file is empty, then the command failed
  raise "Failed to concatenate #{@target} and #{@source}" unless File.size? output

  message.update_attachment @target, content: output.read, name: name,
    mime: 'application/pdf'

  message.delete_attachment @source

rescue
  Wunderbar.error "Failed to concatenate #{@target} and #{@source}"
  raise
ensure
  source.unlink if source
  target.unlink if target
  output.unlink if output
end

{attachments: message.attachments, selected: name}
