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
# Forward an attachment to another destination
#

# extract message
message = Mailbox.find(@message)

# obtain per-user information
_personalize_email(env.user)

########################################################################
#                            forward email                             #
########################################################################

# send confirmation email
task "email #@email" do
  message = Mailbox.find(@message)
  text = message.text_part

  # build new message
  mail = Mail.new
  mail.subject = 'Fwd: ' + message.subject
  mail.to = @destination
  mail.from = @from

  # add forwarded text part
  body = ['-------- Forwarded Message --------']
  body << "Subject: #{message.subject}"
  body << "Date: #{message.date}"
  body << "From: #{message.from}"
  body << "To: #{message.to}"
  body << "cc: #{message.cc.map(&:to_s).join(', ')}" unless message.cc.empty?
  body += ['', text.decoded] if text
  mail.text_part = body.join("\n")

  # add attachment
  mail.attachments[@selected] = {
    mime_type: 'application/pdf',
    content: message.find(@selected).as_pdf.read
  }

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end
