#
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous mail: person.attrs['mail']

if @email_forward  # must agree with email_forward.js.rb

  # report the new values
  _replacement mail: @email_forward

  @email_forward.each do |mail|
    unless mail.match(URI::MailTo::EMAIL_REGEXP)
      _error "Invalid email address '#{mail}'"
      return
    end
    if mail.downcase.end_with? 'apache.org'
      _error "Invalid email address '#{mail}' (must not be apache.org)"
      return
    end
  end

  if  @email_forward.empty?
    _error "Forwarding email address must not be empty!"
    return
  end

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'mail', @email_forward
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
