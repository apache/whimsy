#
# Secretary post-meeting todo list
#

TLPREQ = '/srv/secretary/tlpreq'

date = params[:date].gsub('-', '_')
date.untaint if date =~ /^\d+_\d+_\d+$/
agenda = "board_agenda_#{date}.txt"

# fetch minutes
@minutes = agenda.sub('_agenda_', '_minutes_')
minutes_file = "#{AGENDA_WORK}/#{@minutes.sub('.txt', '.yml')}"
minutes_file.untaint if @minutes =~ /^board_minutes_\d+_\d+_\d+\.txt$/

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

minutes[:todos] ||= {}
todos = minutes[:todos].dup

parsed_agenda = Agenda.parse(agenda, :full)

# iterate over the agenda, finding items where there is either comments or
# minutes that can be forwarded to the PMC
feedback = []
parsed_agenda.each do |item|
  # select exec officer, additional officer, and committee reports
  next unless item[:attach] =~ /^(4[A-Z]|\d|[A-Z]+)$/
  next unless item['chair_email']

  next unless minutes[item['title']] or 
    (item['comments'] and not item['comments'].empty?)

  unless todos[:feedback_sent] and todos[:feedback_sent].include? item['title']
    feedback << item['title'] 
  end
end

########################################################################
#                               Actions                                #
########################################################################

if @remove and env.password
  chairs = ASF::Service.find('pmc-chairs')

  people = @remove.map {|id| ASF::Person.find(id)}

  ASF::LDAP.bind(env.user, env.password) do
    chairs.remove people
  end

  minutes[:todos][:removed] ||= []
  minutes[:todos][:removed] += people.map {|person| person.id}
end

# update committee-info.txt
if (@change || @establish || @terminate) and env.password
  cinfo = "#{ASF::SVN['private/committers/board']}/committee-info.txt"

  todos  = Array(@change) + Array(@establish) + Array(@terminate)
  if todos.length == 1
    title = todos.first['title']
  else
    title = 'board resolutions: ' + todos.map {|todo| todo['name']}.join(', ')
  end

  ASF::SVN.update cinfo, title, env, _ do |tmpdir, contents|
    unless minutes[:todos][:next_month]
      # update list of reports expected next month
      missing = parsed_agenda.
        select {|item| item[:attach] =~ /^[A-Z]+$/ and item['missing']}.
        map {|item| item['title']}
      contents = ASF::Committee.update_next_month(contents, 
        Date.parse(date.gsub('_', '-')), missing, 
        Array(@establish).map {|resolution| resolution['name']})
    end

    # update chairs from establish, change, and terminate resolutions
    chairs = todos.
      map {|resolution| [resolution['name'], resolution['chair']]}.to_h
    contents = ASF::Committee.update_chairs(contents, chairs, @terminate)

    # add people from establish resolutions
    established = Date.parse(date.gsub('_', '-'))
    Array(@establish).each do |resolution|
      item = parsed_agenda.find do |item| 
        item['title'] == resolution['title']
      end

      contents = ASF::Committee.establish(contents, resolution['name'], 
        established, item['people'])
    end

    contents
  end

  minutes[:todos][:next_month] = true
  File.write minutes_file, YAML.dump(minutes)
end

# update LDAP, create victims.txt
if @establish and env.password
  @establish.each do |resolution|
    pmc = resolution['name']

    item = parsed_agenda.find do |item| 
      item['title'] == resolution['title']
    end

    members = item['people'].map {|id, hash| ASF::Person.find(id)}
    people = item['people'].map {|id, hash| [id, hash[:name]]}

    ASF::LDAP.bind(env.user, env.password) do
      guineapig = ASF::Committee::GUINEAPIGS.include?(pmc.downcase)

      # old style definitions
      unless guineapig
        if ASF::Group.find(pmc.downcase).members.empty?
          ASF::Group.add(pmc.downcase, members)
        end

        if ASF::Committee.find(pmc.downcase).members.empty?
          ASF::Committee.add(pmc.downcase, members)
        end
      end

      # new style definitions
      project = ASF::Project[pmc.downcase]
      if not project
        unless ASF::Committee[pmc.downcase]
          ASF::Committee.add(pmc.downcase, members)
        end

        ASF::Project.find(pmc.downcase).create(members, members)
      elsif not guineapig
        # sync project owners with new PMC list
        project.add_owners(members)
        project.remove_owners(project.owners - members)
        project.add_members(members)
      end
    end 
  end

  establish = @establish.map {|resolution| resolution['name']}

  # create 'victims' file for tlpreq tool
  `svn up #{TLPREQ}`
  establish -= Dir["#{TLPREQ}/victims-#{date}.*.txt"].
     map {|name| File.read(name.untaint).lines().map(&:chomp)}.flatten
  unless establish.empty?
    count = Dir["#{TLPREQ}/victims-#{date}.*.txt"].length
    message = "record #{date} approved TLP resolutions"
    ASF::SVN.update TLPREQ, message, env, _ do |tmpdir|
      filename = "victims-#{date}.#{count}.txt"
      contents = establish.join("\n") + "\n"
      File.write "#{tmpdir}/#{filename}", contents
      _.system "svn add #{tmpdir}/#{filename}"
    end
  end
end

# update LDAP and send out congratulatory email
if (@change || @establish) and env.password
  chairs = ASF::Service.find('pmc-chairs')

  todos  = Array(@change) + Array(@establish)
  people = todos.map {|todo| ASF::Person.find(todo['chair'])}.uniq

  # add new chairs to pmc-chairs
  unless (people-chairs.members).empty?
    ASF::LDAP.bind(env.user, env.password) do
      chairs.add people-chairs.members
    end
  end

  # send out congratulations email
  ASF::Mail.configure
  sender = ASF::Person.new(env.user)
  mail = Mail.new do
    from "#{sender.public_name.inspect} <#{sender.id}@apache.org>".untaint

    to people.map {|person|
      "#{person.public_name.inspect} <#{person.id}@apache.org>".untaint
    }.to_a

    cc 'Apache Board <board@apache.org>'

    subject "Congratulations on your new role at Apache"

    body "Dear new PMC chairs,\n\nCongratulations on your new role at " +
    "Apache. I've changed your LDAP privileges to reflect your new " +
    "status.\n\nPlease read this and update the foundation records:\n" +
    "https://svn.apache.org/repos/private/foundation/officers/advice-for-new-pmc-chairs.txt" +
    "\n\nWarm regards,\n\n#{sender.public_name}"
  end

  mail.deliver!
end

########################################################################
#                    Update list of completed todos                    #
########################################################################

if @change
  minutes[:todos][:changed] ||= []
  minutes[:todos][:changed] += @change.map {|resolution| resolution['name']}
end

if @establish
  minutes[:todos][:established] ||= []
  minutes[:todos][:established] += 
    @establish.map {|resolution| resolution['name']}
end

if @terminate
  minutes[:todos][:terminated] ||= []
  minutes[:todos][:terminated] += @terminate
end

unless todos == minutes[:todos]
  File.write minutes_file, YAML.dump(minutes)
end

########################################################################
#                               Response                               #
########################################################################

transitioning = {}
establish = []
terminate = {}
change = []

parsed_agenda.each do |item|
  next unless item[:attach] =~ /^7\w$/
  if item['title'] =~ /^Change (.*?) Chair$/ and item['people']
    pmc = ASF::Committee.find($1).id
    next if Array(minutes[:todos][:changed]).include? pmc
    change << {name: pmc, resolution: item['title'], chair: item['chair']}
    item['people'].keys.each do |person|
      transitioning[ASF::Person.find(person)] = item['title']
    end
  elsif item['title'] =~ /^Establish\s*(.*?)\s*$/ and item['chair']
    pmc = ASF::Committee.find(pmc).id
    next if Array(minutes[:todos][:established]).include? pmc
    establish << {name: pmc, resolution: item['title'], chair: item['chair']}
    transitioning[ASF::Person.find(item['chair'])] = item['title']
  elsif item['title'] =~ /^Terminate\s*(.*?)\s*$/
    pmc = ASF::Committee.find($1).id
    next if Array(minutes[:todos][:terminated]).include? pmc
    terminate[$1] = item['title']
  end
end

add = transitioning.keys - ASF.pmc_chairs
remove = ASF.pmc_chairs - ASF::Committee.pmcs.map(&:chair) - transitioning.keys

_add add.map {|person| {id: person.id, name: person.public_name, 
  email: person.mail.first, resolution: transitioning[person]}}.
  sort_by {|person| person[:id]}
_remove remove.map {|person| {id: person.id, name: person.public_name}}.
  sort_by {|person| person[:id]}
_change change
_establish establish
_terminate terminate.
  map {|name, resolution| {name: name, resolution: resolution}}
_minutes minutes
_feedback feedback
