#
# send reminders for missing board reports
#

ASF::Mail.configure

sent = {}
unsent = []
sent_emails = [] if @sendsummary # initial automated reminder

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
  mail_list = item['mail_list']
  if mail_list
    if @selection == 'inactive'
      cclist << "dev@#{mail_list}.apache.org"
    elsif item[:attach] =~ /^[A-Z]+/
      cclist << "private@#{mail_list}.apache.org"
    else # This is not a PMC, and the mail_list may already include the domain
      mail_list = mail_list + '@apache.org' unless mail_list.include? '@'
      cclist << mail_list
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

  if @sendsummary # initial automated reminder
    # Mustache is not able to iterate over a hash
    sent_emails << {name: item['title'], emails: [mail.to, mail.cc].flatten.join(',')}
  end
  sent[item['title']] = mail.to_s
end

# provide a response to the request
unsent += @pmcs - sent.keys if @pmcs
if @sendsummary # initial automated reminder
  view = {
    meeting: @meeting,
    agenda: @agenda,
    unsent: unsent,
    sent_emails: sent_emails,
  }
  render = AgendaTemplate.render(@summary, view)
  subject = render[:subject]
  body = render[:body]
  mail = Mail.new do
    from from
    to from
    subject subject
    body body
  end
  mail.deliver! unless @dryrun
  sent[:summary] = mail.to_s
end

{count: sent.length, unsent: unsent, sent: sent, dryrun: @dryrun}
