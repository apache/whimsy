#
# File an ICLA:
#  - add files to documents/grants
#  - add entry to officers/grants.txt
#  - respond to original email
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
  mail = Mail.new(message.raw)
  mail.to = @destination

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end
