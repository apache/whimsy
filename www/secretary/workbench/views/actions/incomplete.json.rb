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
  missing_items = []
  missing_items << '- missing or incomplete postal address' if @missing_address == 'true'
  missing_items << '- missing email address' if @missing_email == 'true'
  missing_items << '' if missing_items.size > 0 # add separator
  @missing_items = missing_items.join("\n")
  mail = message.reply(
    from: @from,
    cc: [
      'secretary@apache.org',
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
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
