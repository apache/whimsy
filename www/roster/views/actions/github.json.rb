#
# Update GitHub username attribute for a committer
#

# update LDAP
_ldap.update do
  person = ASF::Person.find(@userid)

  # report the previous value in the response
  _previous githubUsername: person.attrs['githubUsername']

  if @githubuser and not @dryrun
    person.modify 'githubUsername', @githubuser
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
