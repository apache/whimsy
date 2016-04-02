#
# Update LDAP SpamAssassin score attribute for a committer
#
person = ASF::Person.find(@userid)

# update LDAP
if person.public_name != @publicname
  _ldap.update do
    _previous person.public_name

    if @publicname and not @dryrun
      person.modify 'cn', @publicname
    end
  end
end

# determine commit message
if person.icla.legal_name != @legalname
  if person.icla.name != @publicname
    message = "Update legal and public name for #{@userid}"
  else
    message = "Update legal name for #{@userid}"
  end
elsif person.icla.name != @publicname
  message = "Update public name for #{@userid}"
else
  message = nil
end

# update iclas.txt
if message
  icla_txt = ASF::SVN['private/foundation/officers/iclas.txt']
  _svn.update icla_txt, message: message do |dir, text|
    # replace legal and public names in icla record
    userid = Regexp.escape(@userid)
    text[/^#{userid}:(.*?):/, 1] = @legalname
    text[/^#{userid}:.*?:(.*?):/, 1] = @publicname
  
    text
  end
end

# update cache
person.icla.legal_name = @legalname
person.icla.name = @publicname

# return updated committer info
_committer Committer.serialize(@userid, env)
