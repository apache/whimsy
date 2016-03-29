#
# Update LDAP SpamAssassin score attribute for a committer
#

# probably not needed as LDAP will fail anyway, but ensure that the user
# has authority to update fields
unless 
  env.user == @userid or 
  ASF::Service.find('asf-secretary').members.include? ASF::Person.find(env.user)
then
  raise Error.new('unauthorized')
end

# update LDAP
if env.password
  ASF::LDAP.bind(env.user, env.password) do
    person = ASF::Person.find(@userid)

    if @sascore
      person.modify 'asf-sascore', @sascore
    end
  end
else
  STDERR.puts 'unable to access password'
end

# return updated committer info
Committer.serialize(@userid, env)
