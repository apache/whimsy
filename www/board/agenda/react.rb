# redirect root (minus trailing slash) to latest agenda
get "/react" do
  agenda = dir('board_agenda_*.txt').sort.last
  redirect "#{request.path}/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
end

# redirect root to latest agenda
get '/react/' do
  agenda = dir('board_agenda_*.txt').sort.last
  redirect "#{request.path}#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
end

# redirect missing to missing page for the latest agenda
get '/react/missing' do
  agenda = dir('board_agenda_*.txt').sort.last
  response.headers['Location'] = 
    "/react/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/missing"
  status 302
end

# all agenda pages
get %r{/react/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless Agenda.parse agenda, :quick

  @base = "#{env['SCRIPT_NAME']}/react/#{date}/"

  if env['REMOTE_USER']
    userid = env['REMOTE_USER']
  elsif ENV['RACK_ENV'] == 'test'
    userid = env['HTTP_REMOTE_USER'] || 'test'
  elsif env.respond_to? :user
    userid = env.user
  else
    require 'etc'
    userid = Etc.getlogin
  end

  if userid == 'test' and ENV['RACK_ENV'] == 'test'
    username = 'Joe Tester'
  else
    username = ASF::Person.new(userid).public_name
    username ||= Etc.getpwnam(userid)[4].split(',')[0].force_encoding('utf-8')
  end

  pending = Pending.get(userid)
  initials = pending['initials'] || username.gsub(/[^A-Z]/, '').downcase

  if userid == 'test' or ASF::Service['board'].members.map(&:id).include? userid
    role = :director
  elsif ASF::Service['asf-secretary'].members.map(&:id).include? userid
    role = :secretary
  else
    role = :guest
  end

  # determine who is present
  @present = []
  @present_mtime = nil
  file = File.join(AGENDA_WORK, 'sessions', 'present.yml')
  if File.exist?(file) and File.mtime(file) != @present_mtime
    @present_mtime = File.mtime(file)
    @present = YAML.load_file(file)
  end

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: pending,
    username: username,
    firstname: username.split(' ').first.downcase,
    initials: initials,
    online: @present,
    session: Session.user(userid),
    role: role,
    directors: Hash[ASF::Service['board'].members.map {|person| 
      initials = person.public_name.gsub(/[^A-Z]/, '').downcase
      [initials, person.public_name.split(' ').first]
    }],
    websocket: (env['rack.url_scheme'].sub('http', 'ws')) + '://' +
      env['SERVER_NAME'] + env['SCRIPT_NAME'] + '/websocket/'
  }

  @page = {
    path: path,
    query: params['q'],
    agenda: agenda,
    parsed: Agenda[agenda][:parsed],
    digest: Agenda[agenda][:digest],
    etag: Agenda.uptodate(agenda) ? Agenda[agenda][:etag] : nil
  }

  minutes = AGENDA_WORK + '/' + 
    agenda.sub('agenda', 'minutes').sub('.txt', '.yml')
  @page[:minutes] = YAML.load(File.read(minutes)) if File.exist? minutes

  @cssmtime = File.mtime('public/stylesheets/app.css').to_i
  @appmtime = File.mtime('public/react/app.js').to_i

  erb :"react/scaffold.html"
end

# append slash to agenda page if not present
get %r{/react/(\d\d\d\d-\d\d-\d\d)} do |date|
  redirect to("/react/#{date}/")
end

# internally redirect the rest to the main routes
get %r{/react(\/.*)} do |path|
  call env.merge!("PATH_INFO" => path)
end

post %r{/react(\/.*)} do |path|
  call env.merge!("PATH_INFO" => path)
end
