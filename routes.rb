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
  pass unless AgendaCache.parse agenda, :quick

  @base = (env['SCRIPT_URL']||env['PATH_INFO']).chomp(path).untaint
  if env['HTTP_X_WUNDERBAR_BASE']
    @base = File.join(env['HTTP_X_WUNDERBAR_BASE'], @base)
  end

  if ENV['RACK_ENV'] == 'test'
    userid = 'test'
    username = 'Joe Tester'
  elsif env.respond_to? :user
    userid = env.user
    username = ASF::Person.new(userid).public_name
  elsif env['REMOTE_USER']
    userid = env['REMOTE_USER']
    username = ASF::Person.new(userid).public_name
  else
    require 'etc'
    userid = Etc.getlogin
    username = Etc.getpwnam(userid)[4].split(',').first.force_encoding('utf-8')
  end

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: Pending.get(userid),
    username: username,
    firstname: username.split(' ').first.downcase,
    initials: username.gsub(/[^A-Z]/, '').downcase
  }

  @page = {
    date: date,
    path: path,
    query: params['q'],
    agenda: agenda,
    parsed: AgendaCache[agenda][:parsed],
    etag: AgendaCache[agenda][:etag]
  }

  _html :'main'
end

# posted actions
post '/json/:file' do
  _json :"actions/#{params[:file]}"
end

# updates to agenda data
get %r{(\d\d\d\d-\d\d-\d\d).json} do |file|
  file = "board_agenda_#{file.gsub('-','_')}.txt"
  pass unless AgendaCache.parse file, :full

  begin
    _json do
      last_modified AgendaCache[file][:mtime]
      AgendaCache[file][:parsed]
    end
  ensure
    AgendaCache[file][:etag] = headers['ETag']
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
  end
end


get '/events', provides: 'text/event-stream' do
  stream :keep_open do |out|
    events = Events.subscribe
    out.callback {events << :exit}

    loop do
      event = events.pop
      if Hash === event or Array === event
        out << "data: #{JSON.dump(event)}\n\n"
      elsif event == :heartbeat
        out << ":\n"
      elsif event == :exit
        events.unsubscribe
        out.close
        break
      else
        out << "data: #{event.inspect}\n\n"
      end
    end
  end
end

