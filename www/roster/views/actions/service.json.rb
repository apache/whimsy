#
# Add or remove a person from an service group in LDAP
#

if env.password
  person = ASF::Person.find(@id)
  service = ASF::Service.find(@group)

  # update LDAP
  ASF::LDAP.bind(env.user, env.password) do
    if @action == 'add'
      service.add(person)
    elsif @action == 'remove'
      service.remove(person)
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  list = "#{@group} LDAP service"

  details = [person.dn, service.dn]

  from = ASF::Person.find(env.user)

  # default to sending the message to the group
  to = service.members
  to << person unless to.include? person
  to.delete from unless to.length == 1
  to = to.map do |person|
    "#{person.public_name} <#{person.id}@apache.org>"
  end

  # other committees
  to = 'secretary@apache.org' if service.id == 'asf-secretary'
  to = 'board@apache.org' if service.id == 'board'

  # construct email
  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>"
    to to
    bcc "root@apache.org"
    subject "#{person.public_name} #{action} #{list}"
    body "Current roster can be found at:\n\n" +
      "  https://whimsy.apache.org/roster/group/#{service.id}\n\n" +
      "LDAP details:\n\n  #{details.join("\n  ")}"
  end

  # Header for root@'s lovely email filters
  mail.header['X-For-Root'] = 'yes'

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
Group.serialize(@group)
