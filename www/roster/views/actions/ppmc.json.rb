if env.password
  people = @ids.split(',').map {|id| ASF::Person[id]}

  # if target is ONLY icommit, use incubator in the email message, etc.
  # Otherwise, use the project (podling).
  if @targets == ['icommit']
    project = ASF::Project.find('incubator')
  else
    project = ASF::Project[@project]
  end

  # validate arguments
  if @action != 'remove' and people.any? {|person| person.nil?}
    raise ArgumentError.new("ids=#{@ids}") 
  end

  unless @action == 'add' and @targets.include? 'ldap'
    raise ArgumentError.new("project=#{@project}") unless project
  end

  # update LDAP
  if %w(ppmc committer icommit).any? {|target| @targets.include? target}
    ASF::LDAP.bind(env.user, env.password) do
      if @targets.include? 'ldap'
        if @action == 'add'
          project = ASF::Project.find(@project)
          project.create(people)
        end
      elsif @action == 'add'
        project.add_owners(people) if @targets.include? 'ppmc'
        project.add_members(people) if @targets.include? 'committer'
      elsif @action == 'remove'
        project.remove_owners(people) if @targets.include? 'ppmc'
        project.remove_members(people) if @targets.include? 'committer'
      end

      # when adding a commiter to a podling, also add the commiter to
      # the incubator.  For removals, remove the individual as an
      # incubator committer when they are not a committer for any podling
      # and not an IPMC member.
      # TODO What if they still need general incubator karma? See WHIMSY-90
      if @targets.include? 'icommit' or @targets.include? 'committer'
        incubator = ASF::Project.find('incubator')
        icommit = incubator.members
        user = ASF::Person.find(env.user)
        if user.asf_member? or incubator.owners.include? user
          if @action == 'add'
            additions = people - icommit
            incubator.add_members(additions) unless additions.empty?
          else
            removals = people & icommit
            podlings = ASF::Podling.current.map(&:id)
            removals.select! do |person| 
              not incubator.owners.include? person and
              (person.projects.map(&:id) & podlings).empty?
            end
            incubator.remove_members(removals) unless removals.empty?
          end
        end
      end
    end
  end

  # identify what has changed
  if @targets.include? 'mentor'
    target = 'mentors'
  elsif @targets.include? 'ppmc'
    target = 'PPMC'
  else
    target = 'committers'
  end

  # extract people's names (for short lists) or ids (for longer lists)
  if people.length <= 2
    who = people.map {|person| person.public_name}.join(' and ')
  else
    who = people[0..-2].map {|person| person.id}.join(', ') + 
      ', and ' + people.last.id
  end

  # update podlings.xml
  if @targets.include? 'mentor'
    Dir.mktmpdir do |tmpdir|
      # checkout committers/board
      Kernel.system 'svn', 'checkout', '--quiet', '--depth=empty',
        '--no-auth-cache', '--non-interactive',
        '--username', env.user.untaint, '--password', env.password.untaint,
        'https://svn.apache.org/repos/asf/incubator/public/trunk/content',
         tmpdir.untaint

      # read in podlings.xml
      file = File.join(tmpdir, 'podlings.xml')
      Kernel.system 'svn', 'update', '--quiet', file
      podlings = File.read(file)

      pre = /<podling[^>]* resource="#{@project}".*?<\/podling>/m
      people.each do |person|
        id = person.id
        if @action == 'add'
          podlings.sub! pre do |element|
            element.sub! /<mentors>.*<\/mentors>/m do |mentors|
              spaces = mentors[/(\s+)<mentor /, 1] || 
                mentors[/(\s+)<\/mentors>/, 1] + '    '
              mentors[/()\s+<\/mentors>/, 1] = spaces +
                "<mentor username=#{id.inspect}>#{person.public_name}</mentor>"
              mentors
            end
            element
          end
        else
          podlings.sub! pre do |element|
            element.sub! /\s+<mentor username=#{id.inspect}>.*<\/mentor>/, ''
            element
          end
        end
      end

      # write file out to disk
      File.write(file, podlings)

      # commit changes
      rc = Kernel.system 'svn', 'commit', '--quiet',
        '--no-auth-cache', '--non-interactive',
        '--username', env.user.untaint, '--password', env.password.untaint,
        tmpdir.untaint, '--message',
        "#{@project} #{target} #{@action == 'add' ? '+' : '-'}= #{who}".untaint

      if rc
        # update cache
        cache = ASF::Config.get(:cache)
        File.write("#{cache}/podlings.xml", podlings) if Dir.exist? cache
      else
        # die
        raise Exception.new('Update podlings.xml failed')
      end
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  details = people.map {|person| person.dn} + [project.dn]
  from = ASF::Person.find(env.user)

  # draft email
  if @targets == ['icommit']
    mail = Mail.new do
      from "#{from.public_name} <#{from.id}@apache.org>".untaint
      to 'private@incubator.apache.org'
      bcc 'root@apache.org'
      subject "#{who} #{action} incubator #{target}"
      body "Current roster can be found at:\n\n" +
        "  https://whimsy.apache.org/roster/committee/incubator\n\n" +
        "LDAP details:\n\n  #{details.join("\n  ")}"
    end
  else
    ppmc = ASF::Podling.find(@project)

    cc = people.map do |person| 
      "#{person.public_name.inspect} <#{person.id}@apache.org>".untaint
    end

    if ppmc.private_mail_list != 'private@incubator.apache.org'
      cc << 'private@incubator.apache.org'
    end

    mail = Mail.new do
      from "#{from.public_name} <#{from.id}@apache.org>".untaint
      to ppmc.private_mail_list.untaint
      cc cc
      bcc 'root@apache.org'
      subject "#{who} #{action} #{ppmc.display_name} #{target}"
      body "Current roster can be found at:\n\n" +
        "  https://whimsy.apache.org/roster/ppmc/#{ppmc.id}\n\n" +
        "LDAP details:\n\n  #{details.join("\n  ")}"
    end
  end

  # Header for root@'s lovely email filters
  mail.header['X-For-Root'] = 'yes'

  # deliver email
  mail.deliver!
end

# return updated committee info to the client
PPMC.serialize(@project, env)
