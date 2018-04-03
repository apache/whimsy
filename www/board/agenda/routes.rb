#
# Server side Sinatra routes
#

# redirect root to latest agenda
get '/' do
  agenda = dir('board_agenda_*.txt').sort.last
  pass unless agenda
  redirect "#{request.path}#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
end

# redirect shepherd to latest agenda
get '/shepherd' do
  user=ASF::Person.find(env.user).public_name.split(' ').first
  agenda = dir('board_agenda_*.txt').sort.last
  pass unless agenda
  redirect File.dirname(request.path) +
    "/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/shepherd/#{user}"
end

# redirect missing to missing page for the latest agenda
get '/missing' do
  agenda = dir('board_agenda_*.txt').sort.last
  pass unless agenda # is this correct?
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

# enable debugging of the agenda cache
get '/cache.json' do
  _json Agenda.cache
end

# agenda followup
get %r{/(\d\d\d\d-\d\d-\d\d)/followup\.json} do |date|
  pass unless Dir.exist? '/srv/mail/board'

  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless Agenda.parse agenda, :quick
  
  # select agenda items that have comments
  parsed = Agenda[agenda][:parsed]
  followup = parsed.select {|item| not item['comments'].to_s.empty?}.
    map {|item| [item['title'], {comments: item['comments'], 
      shepherd: item['shepherd'], mail_list: item['mail_list'], count: 0}]}.
    to_h
  
  # count number of feedback emails found in the board archive
  start = Time.parse(date)
  months = Dir['/srv/mail/board/*'].sort[-2..-1]
  Dir[*months.map {|month| "#{month}/*"}].each do |file|
    next unless File.mtime(file) > start
    raw = File.read(file).force_encoding(Encoding::BINARY)
    next unless raw =~ /Subject: .*Board feedback on 2017-05-17 (.*) report/
    followup[$1][:count] += 1 if followup[$1]
  end

  # return results
  _json followup
end

# pending items
get %r{/(\d\d\d\d-\d\d-\d\d)/pending\.json} do |date|
  pending = Pending.get(env.user)
  _json pending
end

# agenda digest information
get %r{/(\d\d\d\d-\d\d-\d\d)/digest\.json} do |date|
  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  _json(
    file: agenda,
    digest: Agenda[agenda][:digest],
    etag: Agenda.uptodate(agenda) ? Agenda[agenda][:etag] : nil
  )
end

# feedback
get %r{/(\d\d\d\d-\d\d-\d\d)/feedback.json} do |date|
  @agenda = "board_agenda_#{date.gsub('-', '_')}.txt".untaint
  @dryrun = true
  _json :'actions/feedback'
end

post %r{/(\d\d\d\d-\d\d-\d\d)/feedback.json} do |date|
  @agenda = "board_agenda_#{date.gsub('-', '_')}.txt".untaint
  @dryrun = false
  _json :'actions/feedback'
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

  # determine who is present
  @present = []
  @present_mtime = nil
  file = File.join(AGENDA_WORK, 'sessions', 'present.yml')
  if File.exist?(file) and File.mtime(file) != @present_mtime
    @present_mtime = File.mtime(file)
    @present = YAML.load_file(file)
  end

  if env['SERVER_NAME'] == 'localhost'
    websocket = 'ws://localhost:34234/'  
  else
    websocket = (env['rack.url_scheme'].sub('http', 'ws')) + '://' +
      env['SERVER_NAME'] + env['SCRIPT_NAME'] + '/websocket/'
  end

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: pending,
    username: pending['username'],
    firstname: pending['firstname'],
    initials: pending['initials'],
    online: @present,
    session: Session.user(userid),
    role: pending['role'],
    directors: Hash[ASF::Service['board'].members.map {|person| 
      initials = person.public_name.gsub(/[^A-Z]/, '').downcase
      [initials, person.public_name.split(' ').first]
    }],
    websocket: websocket
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
    unless env.password
      @server[:userid] = nil 
      @server[:role] = nil 
    end

    @page[:parsed] = [
      {title: 'Roll Call', timestamp: @page[:parsed].first['timestamp']}
    ]
    @page[:digest] = nil
    @page[:etag] = nil
    @server[:session] = nil

    # capture all the variable content
    hash = {
      cssmtime: @cssmtime, 
      appmtime: @appmtime, 
      scripts: Wunderbar::Asset.scripts.
        map {|script| [script.path, script.mtime.to_i]}.sort,
      stylesheets: Wunderbar::Asset.stylesheets.
        map {|stylesheet| [stylesheet.path, stylesheet.mtime.to_i]}.sort,
      server: @server, 
      page: @page
    }

    # detect if there were any modifications
    etag Digest::MD5.hexdigest(JSON.dump(hash))

    erb :"bootstrap.html"
  else
    _html :main
  end
end

# append slash to agenda page if not present
get %r{/(\d\d\d\d-\d\d-\d\d)} do |date|
  redirect to("/#{date}/")
end

# post item support
get '/json/post-data' do
  _json :"actions/post-data"
end

# feedback responses 
get '/json/responses' do
  _json :"actions/responses"
end

# posted reports
get '/json/posted-reports' do
  _json :"actions/posted-reports"
end

# podling name searches
get '/json/podlingnamesearch' do
  _json ASF::Podling.namesearch
end

# posted actions
post '/json/:file' do
  _json :"actions/#{params[:file]}"
end

# Raw minutes
get %r{/(\d\d\d\d-\d\d-\d\d).ya?ml} do |file|
  minutes = AGENDA_WORK + '/' + "board_minutes_#{file.gsub('-','_')}.yml"
  pass unless File.exists? minutes
  _text File.read minutes
end

# updates to agenda data
get %r{/(\d\d\d\d-\d\d-\d\d).json} do |file|
  file = "board_agenda_#{file.gsub('-','_')}.txt".untaint
  pass unless Agenda.parse file, :full

  begin
    _json do
      last_modified Agenda[file][:mtime]
      minutes = AGENDA_WORK + '/' + file.sub('_agenda_', '_minutes_').
        sub('.txt', '.yml')

      # merge in minutes, if available
      if File.exists? minutes
        minutes = YAML.load_file(minutes)
        Agenda[file][:parsed].each do |item|
          item[:minutes] = minutes[item['title']] if minutes[item['title']]
        end
      end

      Agenda[file][:parsed]
    end
  ensure
    Agenda[file][:etag] = headers['ETag']
  end
end

# draft committers report
get '/text/committers-report' do
  _text :committers_report
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

get %r{/json/(reminder[12]|non-responsive)} do |reminder|
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

# draft new agenda
get '/new' do
  # extract time and date for next meeting
  @meeting = ASF::Board.nextMeeting
  localtime = ASF::Board::TIMEZONE.utc_to_local(@meeting)
  @time = localtime.strftime('%l:%M%P')

  # retrieve latest committee info
  url = 'private/committers/board/committee-info.txt'
  info = ASF::SVN.getInfo(url, env.user, env.password)
  revision, contents = ASF::SVN.get(url, env.user, env.password)
  ASF::Committee.load_committee_info(contents)

  # Get directors, list of pmcs due to report, and shepherds
  @directors = ASF::Board.directors
  @pmcs = ASF::Board.reporting(@meeting)
  @owner = ASF::Board::ShepherdStream.new

  # build full time zone link
  path = "/worldclock/fixedtime.html?iso=" +
    localtime.strftime('%Y-%m-%dT%H:%M:%S') +
    "&msg=ASF+Board+Meeting&p1=137" # time zone for PST/PDT locality
  @tzlink = "http://www.timeanddate.com/#{path}"

  # try to shorten time zone link
  begin
    shorten = 'http://www.timeanddate.com/createshort.html?url=' +
      CGI.escape(path) + '&confirm=1'
    shorten = URI.parse(shorten).read[/id=selectable>(.*?)</, 1]
    @tzlink = shorten if shorten
  end

  # Get list of unpublished and unapproved minutes
  draft = YAML.load_file(Dir["#{AGENDA_WORK}/board_minutes*.yml"].sort.last)
  @minutes = dir("board_agenda_*.txt").
    map {|file| Date.parse(file[/\d[_\d]+/].gsub('_', '-'))}.
    reject {|date| date >= @meeting.to_date}.
    reject {|date| draft[date.strftime('%B %d, %Y')] == 'approved'}

  template = File.read('templates/agenda.erb')
  @disabled = dir("board_agenda_*.txt").
    include? @meeting.strftime("board_agenda_%Y_%m_%d.txt")
  @agenda = Erubis::Eruby.new(template).result(binding)

  @cssmtime = File.mtime('public/stylesheets/app.css').to_i
  _html :new
end

# post a new agenda
post %r{/(\d\d\d\d-\d\d-\d\d)/} do |date|
  board = 'https://svn.apache.org/repos/private/foundation/board'
  agenda = "board_agenda_#{date.gsub('-', '_')}.txt"
  auth = "--username #{env.user} --password #{env.password}"

  contents = params[:agenda].gsub("\r\n", "\n")

  Dir.mktmpdir do |dir|
    `svn checkout --depth empty #{board} #{dir} #{auth}`
    File.write "#{dir}/#{agenda}", contents
    `svn add #{dir}/#{agenda}`

    `svn update #{dir}/current.txt #{auth}`
    File.unlink "#{dir}/current.txt"
    File.symlink agenda, "#{dir}/current.txt"

    files = ["#{dir}/#{agenda}", "#{dir}/current.txt"]
    `svn commit #{files.join(' ')} --message "Post #{date} agenda" #{auth}`
    Agenda.update_cache agenda, File.join(dir, agenda), contents, false
  end

  redirect to("/#{date}/")
end
