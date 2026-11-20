#
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous sshPublicKey: person.attrs['sshPublicKey']

if @sshkeys  # must agree with sshkeys.js.rb

  # report the new values
  _replacement sshPublicKey: @sshkeys

  # validate key format
  valid_key_re = /^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)\s+[A-Za-z0-9+\/=]+(\s+.*)?$/
  @sshkeys.each do |key|
    unless key.length <= 2048
      _error "SSH key too long (max 2048 characters)"
      return
    end
    unless key =~ valid_key_re
      _error "'#{key[0..20]}...' is invalid: must be a valid SSH public key"
      return
    end
  end

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'sshPublicKey', @sshkeys
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
