#
#  - respond to late membership application
#

# extract message
message = Mailbox.find(@message)
@email = message.from

# obtain per-user information
_personalize_email(env.user)

########################################################################
#                           email submitter                            #
########################################################################

# send email
task "email #@email" do
  to = message.headers[:from]
  @fullname = message.headers[:name]

  # build mail from template
  mail = message.reply(
    subject: @document,
    from: 'secretary@apache.org',
    to: to,
    cc: 'secretary@apache.org',
    body: template('memlate.erb')
  )

  # echo email
  form do
    _message mail
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end
