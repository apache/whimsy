#
# send reminders for missing board reports
#

ASF::Mail.configure

sent = {}
unsent = []

# extract values for common fields
from = @from
unless from
  sender = ASF::Person.find(env.user)
  from = "#{sender.public_name.inspect} <#{sender.id}@apache.org>"
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
    whoTo = 'operations@apache.org'
  else
    whoTo = 'board@apache.org'
  end

  # values to substitute
  view = {
    whoTo: whoTo,
    link: item['title'].gsub(/\W/, '-'),
    project: item['title']
  }

  # apply changes to both subject and the message text itself
  subject = Mustache.render(@subject, view)
  message = Mustache.render(@message, view)

  # cc list
  cclist = []
  if item['mail_list']
    if @selection == 'inactive'
      cclist << "dev@#{item['mail_list']}.apache.org"
    elsif item[:attach] =~ /^[A-Z]+/
      cclist << "private@#{item['mail_list']}.apache.org"
    else
      cclist << "#{item['mail_list']}@apache.org"
    end
  end

  # construct email
  mail = Mail.new do
    from from
    to "#{item['owner']} <#{item['chair_email']}>"
    cc cclist unless cclist.empty?
    subject subject

    body message
  end

  # deliver mail
  mail.deliver! unless @dryrun
  sent[item['title']] = mail.to_s
end

# provide a response to the request
unsent += @pmcs - sent.keys if @pmcs
{count: sent.length, unsent: unsent, sent: sent, dryrun: @dryrun}
