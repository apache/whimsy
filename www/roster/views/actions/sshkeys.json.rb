#
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous sshPublicKey: person.attrs['sshPublicKey']

if @sshkeys  # must agree with sshkeys.js.rb

  # report the new values
  _replacement sshPublicKey: @sshkeys

  # TODO: add validation?

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'sshPublicKey', @sshkeys
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
