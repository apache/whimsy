#
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous asf_pgpKeyFingerprint: person.attrs['asf-pgpKeyFingerprint']

if @pgpkeys  # must agree with pgpkeys.js.rb

  # report the new values
  _replacement pgpKeyFingerprint: @pgpkeys

  fprints = [] # collect the fingerprints
  @pgpkeys.each do |fp|
    fprint = fp.gsub(' ','').upcase
    if fprint =~ /^[0-9A-F]{40}$/
      fprints << fprint
    else
      _error "'#{fp}' is invalid: expecting 40 hex characters (plus optional spaces)"
      return
    end
  end
  # convert to canonical format
  fprints = fprints.uniq.map do |n| # duplicates not allowed
   "%s %s %s %s %s  %s %s %s %s %s" % n.scan(/..../)
  end
  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'asf-pgpKeyFingerprint', fprints
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
