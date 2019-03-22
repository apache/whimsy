#
# Update GitHub username attribute for a committer
#

# update LDAP
_ldap.update do
  person = ASF::Person.find(@userid)

  # report the previous value in the response
  _previous githubUsername: person.attrs['githubUsername']

  if @githubuser and not @dryrun
    # TODO: Hack to deal with single input field on the form
    # multiple entries are currently displayed with commas when editting
    names = @githubuser.split(/[, ]+/).uniq{|n| n.downcase} # duplicates not allowed; case-blind
    person.modify 'githubUsername', names
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
