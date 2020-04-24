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
  # variable for 'The xxx can use'
  @cttee = '(P)PMC'
  @cttee = "Apache #{@podling.display_name} podling" if @podling
  @cttee = "Apache #{@pmc.display_name} PMC" if @pmc
  mail = message.reply(
    from: @from,
    cc: [
      'secretary@apache.org',
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
    body: template('resubmit.erb')
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
