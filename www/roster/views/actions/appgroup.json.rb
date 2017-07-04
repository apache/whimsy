#
# Add or remove a person from an application group in LDAP
#

if env.password
  person = ASF::Person.find(@id)
  group = ASF::AppGroup.find(@group)

  # update LDAP
  ASF::LDAP.bind(env.user, env.password) do
    if @action == 'add'
      group.add(person)
    elsif @action == 'remove'
      group.remove(person)
    end
  end
end

# return updated committee info to the client
Group.serialize(@group)
