#
# Secretary post-meeting todo list
#

TLPREQ = '/srv/secretary/tlpreq'

date = params[:date].gsub('-', '_')
date.untaint if date =~ /^\d+_\d+_\d+$/
agenda = "board_agenda_#{date}.txt"
victims = Dir["#{TLPREQ}/victims-#{date}.*.txt"].
  map {|name| File.read(name.untaint).lines().map(&:chomp)}.flatten

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
end

if @add and env.password
  chairs = ASF::Service.find('pmc-chairs')

  people = @add.select {|id, checked| checked}.
    map {|id, checked| ASF::Person.find(id)}

  ASF::LDAP.bind(env.user, env.password) do
    chairs.add people
  end
end

if @establish and env.password
  establish = @establish.select {|title, checked| checked}.map(&:first)

  Dir.chdir TLPREQ do
    count = Dir["victims-#{date}.*.txt"].length
    filename = "victims-#{date}.#{count}.txt"
    contents = establish.join("\n") + "\n"
    File.write filename, contents
    system "svn add #{filename}"
STDERR.puts user: env.user.tainted?
STDERR.puts password: env.password.tainted?
STDERR.puts filename: filename.tainted?
STDERR.puts date: date.tainted?
    system 'svn', 'commit', '--username', env.user, '--password', env.password,
      filename, '-m', 'record #{date} approved TLP resolutions'
    if $? == 0
      victims += establish
    else
      system "svn rm --force #{filename}"
    end
  end
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
remove = ASF.pmc_chairs - ASF::Committee.list.map(&:chair) - transitioning.keys
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
