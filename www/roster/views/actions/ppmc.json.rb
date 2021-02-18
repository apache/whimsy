if env.password

  # validate ids
  if @action == 'remove'
    people = @ids.split(',').map {|id| ASF::Person.find(id)}
  else
    people = @ids.split(',').map {|id| ASF::Person[id]}
    raise ArgumentError.new("ids=#{@ids}") if people.any? {|person| person.nil?}
  end

  # Don't allow empty list
  raise ArgumentError.new("ids='#{@ids}'") unless people.length > 0

  # if target is ONLY icommit, use incubator in the email message, etc.
  # Otherwise, use the project (podling).
  if @targets == ['icommit']
    project = ASF::Project.find('incubator')
  else
    project = ASF::Project[@project]
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

      # when adding a committer to a podling, also add the committer to
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
    # Person may not exist when ids are renamed
    who = people.map {|person| (person.public_name || person.id )}.join(' and ')
  else
    who = people[0..-2].map {|person| person.id}.join(', ') +
      ', and ' + people.last.id
  end

  # update podlings.xml
  if @targets.include? 'mentor'
    path = File.join(ASF::SVN.svnurl('incubator-content'), 'podlings.xml')
    msg = "#{@project} #{target} #{@action == 'add' ? '+' : '-'}= #{who}"
    ASF::SVN.update(path, msg, env, _, {}) do |tmpdir, podlings|

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
            element.sub! /\s+<mentor username=#{Regexp.escape(id.inspect)}>.*<\/mentor>/, ''
            element
          end
        end
      end

      podlings
    end
  end

  # compose E-mail
  action = (@action == 'add' ? 'added to' : 'removed from')
  details = people.map {|person| person.dn} + [project.dn]
  from = ASF::Person.find(env.user)

  # draft email
  if @targets == ['icommit']
    mail = Mail.new do
      from "#{from.public_name} <#{from.id}@apache.org>"
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
      "#{person.public_name.inspect} <#{person.id}@apache.org>"
    end

    if ppmc.private_mail_list != 'private@incubator.apache.org'
      cc << 'private@incubator.apache.org'
    end

    mail = Mail.new do
      from "#{from.public_name} <#{from.id}@apache.org>"
      to ppmc.private_mail_list
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
