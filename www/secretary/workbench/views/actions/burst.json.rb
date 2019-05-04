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
# burst a document into separate pages
#

message = Mailbox.find(@message)

attachments = []

begin
  source = message.find(@selected).as_pdf

  Dir.mktmpdir do |dir|
    Kernel.system 'pdfseparate', source.path, "#{dir}/page_%d.pdf"

    pages = Dir["#{dir}/*.pdf"].map {|name| name.untaint}
      sort_by {|name| name[/d+/].to_i}

    format = @selected.sub(/\.\w+$/, '') + 
      "-%0#{pages.length.to_s.length}d.pdf"

    pages.each_with_index do |page, index|
      attachments << {
        name: format % (index+1),
        content: File.binread(page), # must use binary read
        mime: 'application/pdf'
      } if File.size? page # skip empty output files
    end
  end

  # Don't replace if no output was produced
  message.replace_attachment @selected, attachments unless attachments.empty?
rescue
  Wunderbar.error "Cannot process #{@selected}"
  raise
ensure
  source.unlink if source
end

{
  attachments: message.attachments, 
  selected: (attachments.empty? ? nil : attachments.first[:name])
}
