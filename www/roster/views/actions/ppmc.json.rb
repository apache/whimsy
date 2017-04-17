if env.password
  people = @ids.split(',').map {|id| ASF::Person.find(id)}
  project = ASF::Project.find(@project)

  # update LDAP
  ASF::LDAP.bind(env.user, env.password) do
    if @action == 'add'
      project.add(people)
    elsif @action == 'remove'
      project.remove(people)
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  details = people.map {|person| person.dn} + [project.dn]
  from = ASF::Person.find(env.user)
  ppmc = ASF::Podling.find(@project)

  # extract people's names (for short lists) or ids (for longer lists)
  if people.length <= 2
    who = people.map {|person| person.public_name}.join(' and ')
  else
    who = people[0..-2].map {|person| person.id}.join(', ') + 
      ', and ' + people.last.id
  end

  # draft email
  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>".untaint
    to ppmc.private_mail_list.untaint
    cc 'private@incubator.apache.org'
    bcc 'root@apache.org'
    subject "#{who} #{action} #{ppmc.display_name} PPMC"
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
PPMC.serialize(@project, env)
