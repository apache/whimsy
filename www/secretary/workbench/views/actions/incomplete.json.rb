# extract message
message = Mailbox.find(@message)

# obtain per-user information
_personalize_email(env.user)

# extract/verify project
_extract_project

########################################################################
#                           email submitter                            #
########################################################################

# The keys below must agree with the checkbox names in parts.js.rb
REASONS = {
  '@missing_address' => 'missing or incomplete postal address',
  '@missing_email' => 'missing email address',
  '@corporate_postal' => 'the postal address does not appear to be a personal postal address',
  '@invalid_public' => 'the public name should be a real name and not a user id',
  '@separate_signature' => 'the document and signature must be sent attached to the same email',
  '@unauthorized_signature' => 'the signature must be from an authorized person, usually a company executive',
  '@empty_form' => 'the form appears to be completely empty',
  '@unreadable_scan' => 'the scan is not readable or not complete',
  '@wrong_identity' => 'the public key does not match the name/email on the form',
  '@validation_failed' => 'gpg validation failed',
  '@signature_not_armored' => 'gpg signature must be detached and ascii-armored',
  '@unsigned' => 'the document appears to be unsigned',
  '@script_font' => 'a name typed in a script font is not a signature',
}

# send rejection email
task "email #{message.from}" do
  # build mail from template
  @email = message.from
  missing_items = []
  REASONS.each do |k, v|
    missing_items << "- #{v}" if instance_variable_get(k) == 'true'
  end
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
