#
# Server side Sinatra routes
#

# redirect root to latest agenda
get '/' do
  agenda = dir('board_agenda_*.txt').sort.last
  response.headers['Location'] = "#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
  status 302
end

# all agenda pages
get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless Agenda.parse agenda, :quick

  @base = (env['SCRIPT_URL']||env['PATH_INFO']).chomp(path).untaint
  if env['HTTP_X_WUNDERBAR_BASE']
    @base = File.join(env['HTTP_X_WUNDERBAR_BASE'], @base)
  end

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

  username = ASF::Person.new(userid).public_name
  username ||= 'Joe Tester' if userid == 'test'
  username ||= Etc.getpwnam(userid)[4].split(',')[0].force_encoding('utf-8')

  pending = Pending.get(userid)
  initials = pending['initials'] || username.gsub(/[^A-Z]/, '').downcase

  if ASF::Auth::DIRECTORS[userid] or userid == 'test'
    role = :director
  elsif %w(clr).include? userid
    role = :secretary
  else
    role = :guest
  end

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: pending,
    username: username,
    firstname: username.split(' ').first.downcase,
    initials: initials,
    online: Events.present,
    role: role
  }

  @page = {
    date: date,
    path: path,
    query: params['q'],
    agenda: agenda,
    parsed: Agenda[agenda][:parsed],
    etag: Agenda[agenda][:etag]
  }

  minutes = AGENDA_WORK + '/' + 
    agenda.sub('agenda', 'minutes').sub('.txt', '.yml')
  @page[:minutes] = YAML.load(File.read(minutes)) if File.exist? minutes

  _html :'main'
end

# posted actions
post '/json/:file' do
  _json :"actions/#{params[:file]}"
end

# updates to agenda data
get %r{(\d\d\d\d-\d\d-\d\d).json} do |file|
  file = "board_agenda_#{file.gsub('-','_')}.txt"
  pass unless Agenda.parse file, :full

  begin
    _json do
      last_modified Agenda[file][:mtime]
      Agenda[file][:parsed]
    end
  ensure
    Agenda[file][:etag] = headers['ETag']
  end
end

# draft minutes
get '/text/minutes/:file' do |file|
  file = "board_minutes_#{file.gsub('-','_')}.txt".untaint
  pass unless dir('board_minutes_*.txt').include? file
  path = File.join(FOUNDATION_BOARD, file)

  _text do
    last_modified File.mtime(path)
    _ File.read(path)
  end
end

# jira project info
get '/json/jira' do
  uri = URI.parse('https://issues.apache.org/jira/rest/api/2/project')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)

  response = http.request(request)
  _json { JSON.parse(response.body).map {|project| project['key']} }
end

# chat log
get %r{/json/chat/(\d\d\d\d_\d\d_\d\d)} do |date|
  log = "#{AGENDA_WORK}/board_agenda_#{date}-chat.yml"
  if File.exist? log
    _json YAML.load(File.read(log))
  else
    _json []
  end
end

# event stream for server sent events (a.k.a EventSource)
get '/events', provides: 'text/event-stream' do
  stream :keep_open do |out|
    events = Events.subscribe(env.user)
    out.callback {events.unsubscribe}

    loop do
      event = events.pop
      if Hash === event or Array === event
        out << "data: #{JSON.dump(event)}\n\n"
      elsif event == :heartbeat
        out << ":\n"
      elsif event == :exit
        out.close
        break
      else
        out << "data: #{event.inspect}\n\n"
      end
    end
  end
end

# draft minutes
get '/text/draft/:file' do |file|
  agenda = "board_agenda_#{file.gsub('-','_')}.txt".untaint
  minutes = AGENDA_WORK + '/' +
    agenda.sub('_agenda_','_minutes_').sub('.txt','.yml')

  _text do
    Dir.chdir(FOUNDATION_BOARD) do
      if Dir['board_agenda_*.txt'].include?(agenda)
        _ Minutes.draft(agenda, minutes)
      else
        halt 404
      end
    end
  end
end

