if env.password
  person = ASF::Person.find(@id)
  project = ASF::Project.find(@ppmc)

  # update LDAP
  ASF::LDAP.bind(env.user, env.password) do
    if @action == 'add'
      project.add(person)
    elsif @action == 'remove'
      project.remove(person)
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  details = [person.dn, project.dn]
  from = ASF::Person.find(env.user)
  ppmc = ASF::Podling.find(@ppmc)

  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>".untaint
    to ppmc.private_mail_list.untaint
    cc 'private@incubator.apache.org'
    bcc 'root@apache.org'
    subject "#{person.public_name} #{action} #{ppmc.display_name} PPMC"
    body "Current roster can be found at:\n\n" +
      "  https://whimsy.apache.org/roster/ppmc/#{ppmc.id}\n\n" +
      "LDAP details:\n\n  #{details.join("\n  ")}"
  end

  # Header for root@'s lovely email filters
  mail.header['X-For-Root'] = 'yes'

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
PPMC.serialize(@ppmc, env)
