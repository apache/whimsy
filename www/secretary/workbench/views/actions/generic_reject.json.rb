# extract message
message = Mailbox.find(@message)

# obtain per-user information
_personalize_email(env.user)

# extract/verify project
_extract_project

########################################################################
#                           email submitter                            #
########################################################################

# send rejection email
task "email #{message.from}" do
  # build mail from template
  @email = message.from
  mail = message.reply(
    from: @from,
    cc: [
      'secretary@apache.org',
      (@pmc.private_mail_list if @pmc), # copy pmc if selected
      @podling&.private_mail_list # copy podling if selected
    ],
    body: template("#{@doctype}.erb")
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
