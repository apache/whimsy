#
# send reminders
#

sent = {}

# utilize smtp without certificate verification
Mail.defaults do
  delivery_method :smtp, openssl_verify_mode: 'none'
end

# extract values for common fields
sender = ASF::Person.find(env.user)
from = "#{sender.public_name} <#{sender.id}@apache.org>".untaint
subject = @subject.untaint

# iterate over the agenda
Agenda.parse(@agenda, :full).each do |item|
  next unless @pmcs.include? item['title']
  next unless item['chair_email']

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

  # construct email
  mail = Mail.new do
    from from
    to "#{item['owner']} <#{item['chair_email']}>".untaint
    subject subject

    if item['mail_list']
      if item[:attach] =~ /^[A-Z]+/
        cc "private@#{item['mail_list']}.apache.org".untaint
      else
        cc "#{item['mail_list']}@apache.org".untaint
      end
    end

    body reminder.untaint
  end

  # deliver mail
  mail.deliver! unless @dryrun
  sent[item['title']] = mail.to_s
end

# provide a response to the request
{count: sent.length, unsent: @pmcs - sent.keys, sent: sent, dryrun: @dryrun}
