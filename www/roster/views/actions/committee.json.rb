if env.password
  pmc = ASF::Committee[@project]
  group = ASF::Group.find(@project) if @targets.include? 'commit'

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
        pmc.add_committers(people) if group
      elsif @action == 'remove'
        pmc.remove_owners(people) if @targets.include? 'pmc'
        pmc.remove_committers(people) if group
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
    Dir.mktmpdir do |tmpdir|
      # checkout committers/board
      Kernel.system 'svn', 'checkout', '--quiet',
        '--no-auth-cache', '--non-interactive',
        '--username', env.user.untaint, '--password', env.password.untaint,
        'https://svn.apache.org/repos/private/committers/board', tmpdir.untaint

      # read in committee-info.txt
      file = File.join(tmpdir, 'committee-info.txt')
      info = File.read(file)

      info.scan(/^\* (?:.|\n)*?\n\s*?\n/).each do |block|
        # find committee
        next unless ASF::Committee.find(block[/\* (.*?)\s+\(/, 1]).id==@project

        # split block into lines
        lines = block.strip.split("\n")

        # add or remove people
        people.each do |person|
          id = person.id
          if @action == 'add'
            unless lines.any? {|line| line.include? "<#{id}@apache.org>"}
              name = "#{person.public_name.ljust(26)} <#{id}@apache.org>"
              time = Time.new.gmtime.strftime('%Y-%m-%d')
              lines << "    #{name.ljust(59)} [#{time}]"
            end
          else
            lines.reject! {|line| line.include? "<#{id}@apache.org>"}
          end
        end

        # replace committee block with new information
        info.sub! block, ([lines.shift] + lines.sort).join("\n") + "\n\n"
        break
      end

      # write file out to disk
      File.write(file, info)

      # commit changes
      rc = Kernel.system 'svn', 'commit', '--quiet',
        '--no-auth-cache', '--non-interactive',
        '--username', env.user.untaint, '--password', env.password.untaint,
        tmpdir.untaint, '--message',
        "#{@project} #{@action == 'add' ? '+' : '-'}= #{who}".untaint

      if rc
        # update cache
        ASF::Committee.parse_committee_info(info)
      else
        # die
        raise Exception.new('Update committee-info.txt failed')
      end
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  if @targets.include? 'pmc'
    list = group ? 'PMC and committers list' : 'PMC list'
  elsif @targets.include? 'info'
    list = 'in committee-info.txt'
  else
    list = 'committers list'
  end

  details = people.map {|person| person.dn}
  if ASF::Committee::GUINEAPIGS.include? pmc.id
    details << "#{pmc.dn};attr=owner" if @targets.include? 'pmc'
    details << "#{pmc.dn};attr=member" if group
  else
    details << pmc.dn if @targets.include? 'pmc'
    details << group.dn if group
  end

  cc = people.map do |person| 
    "#{person.public_name.inspect} <#{person.id}@apache.org>".untaint
  end

  from = ASF::Person.find(env.user)

  # draft email
  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>".untaint
    to "private@#{pmc.mail_list}.apache.org".untaint
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
