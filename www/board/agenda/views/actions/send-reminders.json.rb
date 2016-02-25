#
# send reminders
#

sent = {}
unsent = []

# utilize smtp without certificate verification
Mail.defaults do
  delivery_method :smtp, openssl_verify_mode: 'none'
end

# extract values for common fields
subject = @subject.untaint
from = @from
unless from
  sender = ASF::Person.find(env.user)
  from = "#{sender.public_name} <#{sender.id}@apache.org>".untaint
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
unsent += @pmcs - sent.keys if @pmcs
{count: sent.length, unsent: unsent, sent: sent, dryrun: @dryrun}
