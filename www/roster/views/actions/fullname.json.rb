#
# Update various LDAP attributes for a committer
#
person = ASF::Person.find(@userid)

# update LDAP
# cn is normally the same as public name, but may be different

mods={} # collect the changes

if @publicname and person.attrs['cn'].first != @publicname
  mods['cn'] = @publicname
end

if @commonname and person.attrs['cn'].first != @commonname
  mods['cn'] = @commonname
end

if @givenname and person.attrs['givenName'].first != @givenname
  mods['givenName'] = @givenname
end

if @familyname and person.attrs['sn'].first != @familyname
  mods['sn'] = @familyname
end

# report the previous value in the response
_previous({
  publicname: person.attrs['cn'], 
  givenname: person.attrs['givenName'],
  familyname: person.attrs['sn']
})

if @dryrun
  # TODO report what would have been done
else
  if mods.size > 0 # only if there is something to do
    _ldap.update do
      # report the previous value in the response
      _previous({
        publicname: person.attrs['cn'], 
        givenname: person.attrs['givenName'],
        familyname: person.attrs['sn']
      })
      mods.each do |k,v|
        person.modify k,v
      end
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
  icla_txt = File.join(ASF::SVN['officers'], 'iclas.txt')
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
