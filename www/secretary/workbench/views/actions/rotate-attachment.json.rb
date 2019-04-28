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
  selected = message.find(@selected).as_pdf

  tool = 'pdf270' if @direction.include? 'right'
  tool = 'pdf90' if @direction.include? 'left'
  tool = 'pdf180' if @direction.include? 'flip'

  raise "Invalid direction #{@direction}" unless tool

  Dir.chdir File.dirname(selected.path) do
    Kernel.system tool, '--quiet', '--suffix', 'rotated', selected.path
  end

  output = selected.path.sub(/\.pdf$/, '-rotated.pdf')

  # If output file is empty, then the command failed
  raise "Failed to rotate #{@selected}" unless File.size? output

  name = @selected.sub(/\.\w+$/, '') + '.pdf'

  message.update_attachment @selected, content: IO.binread(output), name: name,
    mime: 'application/pdf'

rescue
  Wunderbar.error "Cannot process #{@selected}"
  raise
ensure
  selected.unlink if selected
  File.unlink output if output and File.exist? output
end

{attachments: message.attachments, selected: name}
