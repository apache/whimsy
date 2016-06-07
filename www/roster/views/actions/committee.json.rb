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
        next unless ASF::Committee.find(block[/\* (.*?)\s+\(/, 1]).id == @pmc

        # split block into lines
        lines = block.strip.split("\n")

        # add or remove person
        if @action == 'add'
          unless lines.any? {|line| line.include? "<#{@id}@apache.org>"}
            name = "#{person.public_name.ljust(26)} <#{@id}@apache.org>"
            time = Time.new.gmtime.strftime('%Y-%m-%d')
            lines << "    #{name.ljust(59)} [#{time}]"
          end
        else
          lines.reject! {|line| line.include? "<#{@id}@apache.org>"}
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
        "#{@pmc} #{@action == 'add' ? '+' : '-'}= #{@id}"

      if rc
        # update cache
        ASF::Committee.parse_committee_info(info)
      else
        # die
        raise Error.new('Update committee-info.txt failed')
      end
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
  # Header for root@'s lovely email filters
  mail.header['X-For-Root'] = 'yes'

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
Committee.serialize(@pmc, env)
