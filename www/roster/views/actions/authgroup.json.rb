#
# Add or remove a person from an authorization group in LDAP
#

if env.password
  person = ASF::Person.find(@id)
  group = ASF::AuthGroup.find(@group)

  # update LDAP
  ASF::LDAP.bind(env.user, env.password) do
    if @action == 'add'
      group.add(person)
    elsif @action == 'remove'
      group.remove(person)
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  list = "#{@group} authorization group"

  details = [person.dn, group.dn]

  from = ASF::Person.find(env.user)

  # default to sending the message to the group
  to = group.members
  to << person unless to.include? person
  to.delete from unless to.length == 1
  to = to.map do |person|
    "#{person.public_name} <#{person.id}@apache.org>"
  end

  # replace with sending to the private@pmc list if this is a pmc owned group
  pmc = ASF::Committee.find(group.id.split('-').first)
  unless pmc.owners.empty?
    to = pmc.mail_list
    to = "private@#{to}.apache.org" unless to.include? '@'
  end

  # other committees
  to = 'fundraising@apache.org' if group.id == 'fundraising'

  # construct email
  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>"
    to to
    bcc "root@apache.org"
    subject "#{person.public_name} #{action} #{list}"
    body "Current roster can be found at:\n\n" +
      "  https://whimsy.apache.org/roster/group/#{group.id}\n\n" +
      "LDAP details:\n\n  #{details.join("\n  ")}"
  end

  # Header for root@'s lovely email filters
  mail.header['X-For-Root'] = 'yes'

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
Group.serialize(@group)
