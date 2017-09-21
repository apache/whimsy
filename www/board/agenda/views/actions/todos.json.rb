#
# Secretary post-meeting todo list
#

TLPREQ = '/srv/secretary/tlpreq'

date = params[:date].gsub('-', '_')
date.untaint if date =~ /^\d+_\d+_\d+$/
agenda = "board_agenda_#{date}.txt"
`svn up #{TLPREQ}`
victims = Dir["#{TLPREQ}/victims-#{date}.*.txt"].
  map {|name| File.read(name.untaint).lines().map(&:chomp)}.flatten

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

# iterate over the agenda, finding items where there is either comments or
# minutes that can be forwarded to the PMC
feedback = []
Agenda.parse(agenda, :full).each do |item|
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

  people = @remove.select {|id, checked| checked}.
    map {|id, checked| ASF::Person.find(id)}

  ASF::LDAP.bind(env.user, env.password) do
    chairs.remove people
  end

  minutes[:todos][:removed] ||= []
  minutes[:todos][:removed] += people.map {|person| person.id}
end

if @add and env.password
  chairs = ASF::Service.find('pmc-chairs')

  people = @add.select {|id, checked| checked}.
    map {|id, checked| ASF::Person.find(id)}

  ASF::LDAP.bind(env.user, env.password) do
    chairs.add people
  end

  # send out congratulations email
  ASF::Mail.configure
  sender = ASF::Person.new(env.user)
  mail = Mail.new do
    from "#{sender.public_name.inspect} <#{sender.id}@apache.org>".untaint

    to people.map do |person|
      "#{person.public_name.inspect} <#{person.id}@apache.org>".untaint
    end

    cc 'Apache Board <board@apache.org>'

    subject "Congratulations on your new role at Apache"

    body "Dear new PMC chairs,\n\nCongratulations on your new role at " +
    "Apache. I've changed your LDAP privileges to reflect your new " +
    "status.\n\nPlease read this and update the foundation records:\n" +
    "https://svn.apache.org/repos/private/foundation/officers/advice-for-new-pmc-chairs.txt" +
    "\n\nWarm regards,\n\n#{sender.public_name}"
  end

  mail.deliver!

  minutes[:todos][:added] ||= []
  minutes[:todos][:added] += people.map {|person| person.id}
end

if @establish and env.password
  establish = @establish.select {|title, checked| checked}.map(&:first)

  # common to all establish resolutions
  chairs = ASF::Service.find('pmc-chairs')
  cinfo = "#{ASF::SVN['private/committers/board']}/committee-info.txt"
  established = Date.parse(date.gsub('_', '-'))

  # update LDAP, committee-info.txt
  establish.each do |pmc|
    resolution = Agenda.parse(agenda, :full).find do |item| 
      item['title'] == "Establish #{pmc}"
    end

    chair = ASF::Person.find(resolution['chair'])
    members = resolution['people'].map {|id, hash| ASF::Person.find(id)}
    people = resolution['people'].map {|id, hash| [id, hash[:name]]}

    ASF::SVN.update cinfo, resolution['title'], env, _ do |tmpdir, contents|
      ASF::Committee.establish(contents, pmc, established, people)
    end

    ASF::LDAP.bind(env.user, env.password) do
      chairs.add [chair] unless chairs.members.include? chair
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
        project.create(members, members)
      elsif not guineapig
        # sync project owners with new PMC list
        project.add_owners(members)
        project.remove_owners(project.owners - members)
        project.add_members(members)
      end
    end 
  end

  # create 'victims' file for tlpreq tool
  count = Dir["#{TLPREQ}/victims-#{date}.*.txt"].length
  message = "record #{date} approved TLP resolutions"
  ASF::SVN.update TLPREQ, message, env, _ do |tmpdir|
    filename = "victims-#{date}.#{count}.txt"
    contents = establish.join("\n") + "\n"
    File.write "#{tmpdir}/#{filename}", contents
    _.system "svn add #{tmpdir}/#{filename}"
  end
  victims += establish

  minutes[:todos][:established] ||= []
  minutes[:todos][:established] += establish
end

unless todos == minutes[:todos]
  File.write minutes_file, YAML.dump(minutes)
end

########################################################################
#                               Response                               #
########################################################################

transitioning = {}
establish = {}
terminate = {}

Agenda.parse(agenda, :full).each do |item|
  next unless item[:attach] =~ /^7\w$/
  if item['title'] =~ /^Change .*? Chair$/ and item['people']
    item['people'].keys.each do |person|
      transitioning[ASF::Person.find(person)] = item['title']
    end
  elsif item['title'] =~ /^Establish\s*(.*?)\s*$/ and item['chair']
    establish[$1] = item['title']
    transitioning[ASF::Person.find(item['chair'])] = item['title']
  elsif item['title'] =~ /^Terminate\s*(.*?)\s*$/
    terminate[$1] = item['title']
  end
end

add = transitioning.keys - ASF.pmc_chairs
remove = ASF.pmc_chairs - ASF::Committee.pmcs.map(&:chair) - transitioning.keys
victims.each {|victim| establish.delete victim}

_add add.map {|person| {id: person.id, name: person.public_name, 
  email: person.mail.first, resolution: transitioning[person]}}.
  sort_by {|person| person[:id]}
_remove remove.map {|person| {id: person.id, name: person.public_name}}.
  sort_by {|person| person[:id]}
_establish establish.
  map {|name, resolution| {name: name, resolution: resolution}}
_terminate terminate.
  map {|name, resolution| {name: name, resolution: resolution}}
_minutes minutes
_feedback feedback
