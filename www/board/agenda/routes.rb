#
# Server side Sinatra routes
#

# temporary
get %r{^/(\d\d\d\d-\d\d-\d\d)/feedback$} do |date|
  _html :feedback
end
get %r{^/(\d\d\d\d-\d\d-\d\d)/feedback.json$} do |date|
  @agenda = "board_agenda_#{date.gsub('-', '_')}.txt".untaint
  @dryrun = true
  _json :'actions/feedback'
end
post %r{^/(\d\d\d\d-\d\d-\d\d)/feedback.json$} do |date|
  @agenda = "board_agenda_#{date.gsub('-', '_')}.txt".untaint
  @dryrun = false
  _json :'actions/feedback'
end

# redirect root to latest agenda
get '/' do
  agenda = dir('board_agenda_*.txt').sort.last
  redirect "#{request.path}#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
end

# redirect missing to missing page for the latest agenda
get '/missing' do
  agenda = dir('board_agenda_*.txt').sort.last
  response.headers['Location'] = 
    "#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/missing"
  status 302
end

get '/session.json' do
  _json do
    {session: Session.user(env.user)}
  end
end

# for debugging purposes
get '/env' do
  content_type 'text/plain'

  asset = {
    path: Wunderbar::Asset.path,
    root: Wunderbar::Asset.root,
    virtual: Wunderbar::Asset.virtual,
    scripts: Wunderbar::Asset.scripts.map do |script|
     {path: script.path} 
    end
  }

  JSON.pretty_generate(env: env, ENV: ENV.to_h, asset: asset)
end

# all agenda pages
get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless Agenda.parse agenda, :quick

  @base = "#{env['SCRIPT_NAME']}/#{date}/"

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

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: pending,
    username: username,
    firstname: username.split(' ').first.downcase,
    initials: initials,
    online: IPC.present,
    session: Session.user(userid),
    role: role,
    directors: Hash[ASF::Service['board'].members.map {|person| 
      initials = person.public_name.gsub(/[^A-Z]/, '').downcase
      [initials, person.public_name.split(' ').first]
    }]
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
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i

  if path == 'bootstrap.html'
    @page[:parsed] = [@page[:parsed].first]
    @page[:digest] = nil
    @page[:etag] = nil
    @server[:session] = nil
    _html :bootstrap
  else
    _html :main
  end
end

# append slash to agenda page if not present
get %r{^/(\d\d\d\d-\d\d-\d\d)$} do |date|
  redirect to("/#{date}/")
end

# posted reports
get '/json/posted-reports' do
  _json :"actions/posted-reports"
end

# posted actions
post '/json/:file' do
  _json :"actions/#{params[:file]}"
end

# Raw minutes
get %r{(\d\d\d\d-\d\d-\d\d).ya?ml} do |file|
  minutes = AGENDA_WORK + '/' + "board_minutes_#{file.gsub('-','_')}.yml"
  pass unless File.exists? minutes
  _text File.read minutes
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

# get list of committers (for use in roll-call)
get '/json/committers' do
  _json do
    members = ASF.search_one(ASF::Group.base, "cn=member", 'memberUid').first
    members = Hash[members.map {|name| [name, true]}]
    ASF.search_one(ASF::Person.base, 'uid=*', ['uid', 'cn']).
      map {|person| {id: person['uid'].first, 
        member: members[person['uid'].first] || false,
        name: person['cn'].first.force_encoding('utf-8')}}.
      sort_by {|person| person[:name].downcase.unicode_normalize(:nfd)}
  end
end

# Secretary post-meeting todos
get '/json/secretary-todos/:date' do
  _json :'actions/todos'
end

post '/json/secretary-todos/:date' do
  _json :'actions/todos'
end

# potential actions
get '/json/potential-actions' do
  _json :'actions/potential-actions'
end

get %r{/json/(reminder[12])} do |reminder|
  @reminder = reminder
  _json :'actions/reminder-text'
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

# historical comments
get '/json/historical-comments' do
  _json HistoricalComments.comments
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
