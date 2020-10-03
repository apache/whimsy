if env.password
  pmc = ASF::Committee[@project]

  # validate arguments
  if @action == 'remove'
    people = @ids.split(',').map {|id| ASF::Person.find(id)}
  else
    people = @ids.split(',').map {|id| ASF::Person[id]}
    raise ArgumentError.new("One or more null entries found: '#{@ids}'") if people.any? {|person| person.nil?}
  end

  # Don't allow empty list
  raise ArgumentError.new("No valid entries found: '#{@ids}'") unless people.length > 0

  raise ArgumentError.new("project=#{@project}") unless pmc

  # update LDAP
  if @targets.include? 'pmc' or @targets.include? 'commit'
    ASF::LDAP.bind(env.user, env.password) do
      if @action == 'add'
        pmc.add_owners(people) if @targets.include? 'pmc'
        pmc.add_committers(people) if @targets.include? 'commit'
      elsif @action == 'remove'
        pmc.remove_owners(people) if @targets.include? 'pmc'
        pmc.remove_committers(people) if @targets.include? 'commit'
      end
    end
  end

  # extract people's names (for short lists) or ids (for longer lists)
  if people.length <= 2
    who = people.map {|person| person.public_name || person.id}.join(' and ')
  else
    who = people[0..-2].map {|person| person.id}.join(', ') +
      ', and ' + people.last.id
  end

  # update committee-info.txt
  if @targets.include? 'info'
    message = "#{@project} #{@action == 'add' ? '+' : '-'}= #{who}"
    ASF::SVN.updateCI message, env do |contents|
      contents = ASF::Committee.update_roster(contents, @project, people, @action)
      contents
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  if @targets.include? 'pmc'
    # must use () to enclose method parameter below as ? binds tighter
    list = @targets.include?('commit') ? 'PMC and committers list' : 'PMC list'
  elsif @targets.include? 'info'
    list = 'in committee-info.txt'
  else
    list = 'committers list'
  end

  details = people.map {|person| person.dn}
  details << "#{pmc.dn};attr=owner" if @targets.include? 'pmc'
  details << "#{pmc.dn};attr=member" if @targets.include? 'commit'

  cc = people.map do |person|
    "#{person.public_name.inspect} <#{person.id}@apache.org>"
  end

  from = ASF::Person.find(env.user)

  # draft email
  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>"
    to "private@#{pmc.mail_list}.apache.org"
    cc cc
    bcc "root@apache.org"
    subject "#{who} #{action} #{pmc.display_name} #{list}"
    body "Current roster can be found at:\n\n" +
      "  https://whimsy.apache.org/roster/committee/#{pmc.id}\n\n" +
      "LDAP details:\n\n  #{details.join("\n  ")}"
  end

  # Header for root@'s lovely email filters
  mail.header['X-For-Root'] = 'yes'

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
Committee.serialize(@project, env)
