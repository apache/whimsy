if env.password
  person = ASF::Person.find(@id)
  pmc = ASF::Committee.find(@pmc) if @targets.include? 'pmc'
  group = ASF::Group.find(@pmc) if @targets.include? 'commit'

  # update LDAP
  ASF::LDAP.bind(env.user, env.password) do
    if @action == 'add'
      pmc.add(person) if pmc
      group.add(person) if group
    elsif @action == 'remove'
      pmc.remove(person) if pmc
      group.remove(person) if group
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  if pmc
    list = group ? 'PMC and committers list' : 'PMC list'
  else
    list = 'committers list'
  end

  details = [person.dn]
  details << group.dn if group
  details << pmc.dn if pmc

  pmc ||= ASF::Committee.find(@pmc)
  from = ASF::Person.find(env.user)

  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>".untaint
    to "private@#{pmc.mail_list}.apache.org".untaint
    bcc "root@apache.org"
    subject "#{person.public_name} #{action} #{pmc.display_name} #{list}"
    body "Current roster can be found at:\n\n" +
      "  https://whimsy.apache.org/roster/committee/#{pmc.id}\n\n" +
      "LDAP details:\n\n  #{details.join("\n  ")}"
  end

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
Committee.serialize(@pmc, env)
