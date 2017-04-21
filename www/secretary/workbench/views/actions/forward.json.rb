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
