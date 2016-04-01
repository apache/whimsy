#
# Update LDAP SpamAssassin score attribute for a committer
#

# update LDAP
_ldap.update do
  person = ASF::Person.find(@userid)

  # report the previous value in the response
  _previous sascore: person.attrs['asf-sascore']

  if @sascore and not @dryrun
    person.modify 'asf-sascore', @sascore
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
