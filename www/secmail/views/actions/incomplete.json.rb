# extract message
message = Mailbox.find(@message)

# obtain per-user information
_personalize_email(env.user)

########################################################################
#                           email submitter                            #
########################################################################

# send rejection email
task "email #{message.from}" do
  # build mail from template
  @email = message.from
  mail = message.reply(
    from: @from,
    cc: 'secretary@apache.org',
    body: template('incomplete.erb')
  )

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end
