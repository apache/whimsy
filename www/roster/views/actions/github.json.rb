#
# Update GitHub username attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous githubUsername: person.attrs['githubUsername']

if @githubuser

  # report the new values
  _replacement githubUsername: @githubuser

  @githubuser.each do |name|
    # Should agree with the validation in github.js.rb
    unless name =~ /^[-0-9a-zA-Z]+$/ # TODO: might need extending?
      _error "'#{name}' is invalid: must be alphanumeric (or -)"
      return
    end
    # TODO: perhaps check that https://github.com/name exists?
  end

  unless @dryrun
    names = @githubuser.uniq{|n| n.downcase} # duplicates not allowed; case-blind
    # update LDAP
    _ldap.update do
       person.modify 'githubUsername', names
    end
  end

end

# return updated committer info
_committer Committer.serialize(@userid, env)
