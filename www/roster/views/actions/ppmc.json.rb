if env.password
  people = @ids.split(',').map {|id| ASF::Person.find(id)}
  project = ASF::Project.find(@project)

  # update LDAP
  if @targets.include? 'ppmc' or @targets.include? 'committer'
    ASF::LDAP.bind(env.user, env.password) do
      if @action == 'add'
        project.add_owners(people) if @targets.include? 'ppmc'
        project.add_members(people) if @targets.include? 'committer'
      elsif @action == 'remove'
        project.remove_owners(people) if @targets.include? 'ppmc'
        project.remove_members(people) if @targets.include? 'committer'
      end
    end
  end

  # identify what has changed
  if @targets.include? 'mentor'
    target = 'mentors'
  elsif @targets.include? 'ppmc'
    target = 'PMC'
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
        "#{@project} #{target} #{@action == 'add' ? '+' : '-'}= #{who}"

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
  ppmc = ASF::Podling.find(@project)

  # draft email
  mail = Mail.new do
    from "#{from.public_name} <#{from.id}@apache.org>".untaint
    to ppmc.private_mail_list.untaint
    cc 'private@incubator.apache.org'
    bcc 'root@apache.org'
    subject "#{who} #{action} #{ppmc.display_name} #{target}"
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
