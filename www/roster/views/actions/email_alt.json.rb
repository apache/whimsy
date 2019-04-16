#
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous alt_email: person.alt_email # returns empty array if not defined

if @email_alt  # must agree with email_alt.js.rb

  # report the new values
  _replacement alt_email: @email_alt

  @email_alt.each do |mail|
    unless mail.match(URI::MailTo::EMAIL_REGEXP)
      _error "Invalid email address '#{mail}'"
      return
    end
    if mail.downcase.end_with? 'apache.org'
      _error "Invalid email address '#{mail}' (must not be apache.org)"
      return
    end
  end

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'asf-altEmail', @email_alt
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
