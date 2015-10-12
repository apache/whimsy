#
# send reminders
#

sent = []

# utilize smtp without certificate verification
Mail.defaults do
  delivery_method :smtp, openssl_verify_mode: 'none'
end

# extract values for common fields
sender = ASF::Person.find(env.user)
from = "#{sender.public_name} <#{sender.id}@apache.org>"
subject = @subject

# iterate over the agenda
Agenda.parse(@agenda, :full).each do |item|
  next unless @pmcs.include? item['title']

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
    to "#{item['owner']} <#{item['chair_email']}>"
    subject subject

    if item['mail_list']
      if item[:attach] =~ /^[A-Z]+/
        cc "private@#{item['mail_list']}.apache.org"
      else
        cc "#{item['mail_list']}@apache.org"
      end
    end

    body reminder
  end

  # deliver mail
  mail.deliver!
  sent << item['title']
end

# provide a response to the request
{count: sent.length, unsent: @pmcs - sent}
