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
# send reminders
#

ASF::Mail.configure

sent = {}
unsent = []

# extract values for common fields
from = @from
unless from
  sender = ASF::Person.find(env.user)
  from = "#{sender.public_name.inspect} <#{sender.id}@apache.org>".untaint
end

# iterate over the agenda
Agenda.parse(@agenda, :full).each do |item|
  # decide whether or not to skip the report based on the setting of @pmcs
  next if @pmcs and not @pmcs.include? item['title']
  next if not @pmcs and not item['report'].to_s.empty?

  # select exec officer, additional officer, and committee reports
  next unless item[:attach] =~ /^(4[A-Z]|\d|[A-Z]+)$/

  # bail if chair email can't be found
  unless item['chair_email']
    unsent << item['title']
    next
  end

  # substitute [whoTo] values
  if item['to'] == 'president'
    reminder = @message.gsub('[whoTo]', 'operations@apache.org')
  else
    reminder = @message.gsub('[whoTo]', 'board@apache.org')
  end

  # substitute [link] values
  reminder.gsub! '[link]', item['title'].gsub(/\W/, '-')

  # substitute [project] values
  reminder.gsub! '[project]', item['title'].gsub(/\W/, '-')
  subject = @subject.gsub('[project]', item['title']).untaint

  # cc list
  cclist = []
  if item['mail_list']
    if @selection == 'inactive'
      cclist << "dev@#{item['mail_list']}.apache.org".untaint
    elsif item[:attach] =~ /^[A-Z]+/
      cclist << "private@#{item['mail_list']}.apache.org".untaint
    else
      cclist << "#{item['mail_list']}@apache.org".untaint
    end
  end

  # construct email
  mail = Mail.new do
    from from
    to "#{item['owner']} <#{item['chair_email']}>".untaint
    cc cclist unless cclist.empty?
    subject subject

    body reminder.untaint
  end

  # deliver mail
  mail.deliver! unless @dryrun
  sent[item['title']] = mail.to_s
end

# provide a response to the request
unsent += @pmcs - sent.keys if @pmcs
{count: sent.length, unsent: unsent, sent: sent, dryrun: @dryrun}
