#
# Server side Sinatra routes
#

require 'whimsy/asf/status'
UNAVAILABLE = Status.updates_disallowed_reason # are updates disallowed?

# redirect root to latest agenda
get '/' do
  agenda = dir('board_agenda_*.txt').max
  pass unless agenda
  redirect "#{request.path}#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
end

# alias for latest agenda
get '/latest/' do
  agenda = dir('board_agenda_*.txt').max
  pass unless agenda
  call env.merge(
    'PATH_INFO' => "/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/"
  )
end

# alias for latest agenda in JSON format
get '/latest.json' do
  agenda = dir('board_agenda_*.txt').max
  pass unless agenda
  call env.merge!(
    'PATH_INFO' => "/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}.json"
  )
end

get '/calendar.json' do
  _json do
    {
      nextMeeting: ASF::Board.nextMeeting.iso8601,
      calendar: ASF::Board.calendar.map(&:iso8601),
      agendas: dir('board_agenda_*.txt').sort,
      drafts: dir('board_minutes_*.txt').sort
    }
  end
end

# icon
get '/whimsy.svg' do
  send_file File.expand_path('../../../whimsy.svg', __FILE__),
    type: 'image/svg+xml'
end

# Progress Web App Manfest
get '/manifest.json' do
  @svgmtime = File.mtime(File.expand_path('../../../whimsy.svg', __FILE__)).to_i
  @pngmtime = File.mtime(File.expand_path('../public/whimsy.png', __FILE__)).to_i

  # capture all the variable content
  hash = {
    source: File.read("#{settings.views}/manifest.json.erb"),
    svgmtime: @svgmtime
  }

  # detect if there were any modifications
  etag Digest::MD5.hexdigest(JSON.dump(hash))

  content_type 'application/json'
  erb :"manifest.json"
end

# redirect shepherd to latest agenda
get '/shepherd' do
  user = ASF::Person.find(env.user).public_name.split(' ').first
  agenda = dir('board_agenda_*.txt').max
  pass unless agenda
  redirect File.dirname(request.path) +
           "/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/shepherd/#{user}"
end

# redirect missing to missing page for the latest agenda
get '/missing' do
  agenda = dir('board_agenda_*.txt').max
  pass unless agenda # this will result in a 404

  # Support for sending out reminders before the agenda is created.
  # Useful in cases where the agenda creation is delayed due to
  # a board election.
  if agenda < Date.today.strftime('board_agenda_%Y_%m_%d.txt')
    # update in memory cache with a dummy agenda.  The only relevant
    # part of the agenda that matters for this operation is the list
    # of pmcs (@pmcs).
    template = File.join(ASF::SVN['foundation_board'], 'templates', 'board_agenda.erb')
    @meeting = ASF::Board.nextMeeting
    agenda = @meeting.strftime('board_agenda_%Y_%m_%d.txt')
    @directors = ['TBD']
    @minutes = []
    @owner = ASF::Board::ShepherdStream.new
    @pmcs = ASF::Board.reporting(@meeting)
    contents = Erubis::Eruby.new(IO.read(template)).result(binding)
    Agenda.update_cache(agenda, nil, contents, true)
  end

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

  agenda = "board_agenda_#{date.gsub('-', '_')}.txt"
  pass unless Agenda.parse agenda, :quick

  # select agenda items that have comments
  parsed = Agenda[agenda][:parsed]
  followup = parsed.reject {|item| item['comments'].to_s.empty?}.
    map {|item| [item['title'], {comments: item['comments'],
                                 shepherd: item['shepherd'],
                                 mail_list: item['mail_list'],
                                 count: 0}]
        }.to_h

  # count number of feedback emails found in the board archive
  start = Time.parse(date)
  months = Dir['/srv/mail/board/*'].sort[-2..-1]
  Dir[*months.map {|month| "#{month}/*"}].each do |file|
    next unless File.mtime(file) > start
    raw = File.read(file).force_encoding(Encoding::BINARY)
    next unless raw =~ /Subject: .*Board feedback on #{date} (.*) report/
    followup[$1][:count] += 1 if followup[$1]
  end

  # return results
  _json followup
end

# pending items
get %r{/(\d\d\d\d-\d\d-\d\d)/pending\.json} do
  pending = Pending.get(env.user)
  _json pending
end

# agenda digest information
get %r{/(\d\d\d\d-\d\d-\d\d)/digest\.json} do |date|
  agenda = "board_agenda_#{date.gsub('-', '_')}.txt"
  _json(
    {
      agenda: {
        file: agenda,
        digest: Agenda[agenda][:digest],
        etag: Agenda.uptodate(agenda) ? Agenda[agenda][:etag] : nil
      },
      reporter: Reporter.digest
    }
  )
end

# feedback
get %r{/(\d\d\d\d-\d\d-\d\d)/feedback.json} do |date|
  @agenda = "board_agenda_#{date.gsub('-', '_')}.txt"
  @dryrun = true
  _json :'actions/feedback'
end

post %r{/(\d\d\d\d-\d\d-\d\d)/feedback.json} do |date|
  return [503, UNAVAILABLE] if UNAVAILABLE

  @agenda = "board_agenda_#{date.gsub('-', '_')}.txt"
  @dryrun = false
  _json :'actions/feedback'
end

def server
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

  pending = Pending.get(userid)

  # determine who is present
  @present = []
  @present_mtime = nil
  file = File.join(AGENDA_WORK, 'sessions', 'present.yml')
  if File.exist?(file) and File.mtime(file) != @present_mtime
    @present_mtime = File.mtime(file)
    @present = YAML.load_file(file).
      reject {|name| name =~ /^board_agenda_[_\d]+$/}
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
      initials = begin
        YAML.load_file(File.join(AGENDA_WORK, "#{person.id}.yml"))['initials']
      rescue
        person.public_name.gsub(/[^A-Z]/, '').downcase
      end
      [initials, person.public_name.split(' ').first]
    }],
    websocket: websocket
  }
end

get '/server.json' do
  _json server
end

# all agenda pages
get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  agenda = "board_agenda_#{date.gsub('-', '_')}.txt"
  pass unless Agenda.parse agenda, :quick

  @base = "#{env['SCRIPT_NAME']}/#{date}/"

  @server = server

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
  @page[:minutes] = YAML.safe_load(File.read(minutes), permitted_classes: [Symbol]) if File.exist? minutes

  @cssmtime = File.mtime('public/stylesheets/app.css').to_i
  @manmtime = File.mtime("#{settings.views}/manifest.json.erb").to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i
  @server[:swmtime] = File.mtime("#{settings.views}/sw.js.rb").to_i

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
      source: File.read("#{settings.views}/bootstrap.html.erb"),
      cssmtime: @cssmtime,
      appmtime: @appmtime,
      manmtime: @manmtime,
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

post '/json/posted-reports' do
  return [503, UNAVAILABLE] if UNAVAILABLE

  _json :"actions/posted-reports"
end

# podling name searches
get '/json/podlingnamesearch' do
  _json ASF::Podling.namesearch
end

# podling name searches
get '/json/reporter' do
  _json Reporter.drafts(env)
end

# posted actions
post '/json/:file' do
  return [503, UNAVAILABLE] if UNAVAILABLE

  _json :"actions/#{params[:file]}"
end

# Raw minutes
get %r{/(\d\d\d\d-\d\d-\d\d).ya?ml} do |file|
  minutes = AGENDA_WORK + '/' + "board_minutes_#{file.gsub('-', '_')}.yml"
  pass unless File.exist? minutes
  _text File.read minutes
end

# updates to agenda data
get %r{/(\d\d\d\d-\d\d-\d\d).json} do |date|
  file = "board_agenda_#{date.gsub('-', '_')}.txt"
  pass unless Agenda.parse file, :full

  begin
    _json do
      last_modified Agenda[file][:mtime]
      minutes_file = AGENDA_WORK + '/' + file.sub('_agenda_', '_minutes_').
        sub('.txt', '.yml')

      # merge in minutes, if available
      if File.exist? minutes_file
        minutes = YAML.load_file(minutes_file)
        Agenda[file][:parsed].each do |item|
          item[:minutes] = minutes[item['title']] if minutes[item['title']]
        end
      end

      agenda = Agenda[file][:parsed]

      # filter list for non-PMC chairs and non-officers
      user = env.respond_to?(:user) && ASF::Person.find(env.user)
      unless !user or user.asf_member? or ASF.pmc_chairs.include? user
        status 206 # Partial Content
        committees = user.committees.map(&:display_name)
        agenda = agenda.select {|item| committees.include? item['title']}
      end

      agenda
    end
  ensure
    Agenda[file][:etag] = headers['ETag']
  end
end

# draft committers report
get %r{/text/summary/(\d\d\d\d-\d\d-\d\d)} do |date|
  @date = date.gsub('-', '_')
  _text :committers_report
end

# draft minutes
get '/text/minutes/:file' do |file|
  file = "board_minutes_#{file.gsub('-', '_')}.txt"
  if dir('board_minutes_*.txt').include? file
    path = File.join(FOUNDATION_BOARD, file)
  elsif not Dir[File.join(ASF::SVN['minutes'], file[/\d+/], file)].empty?
    path = File.join(ASF::SVN['minutes'], file[/\d+/], file)
  else
    pass
  end

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
  return [503, UNAVAILABLE] if UNAVAILABLE

  _json :'actions/todos'
end

post '/json/secretary-todos/:date' do
  return [503, UNAVAILABLE] if UNAVAILABLE

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
    _json YAML.safe_load(File.read(log), permitted_classes: [Symbol])
  else
    _json []
  end
end

# historical comments, filtered to only include the list of projects which
# the user is a member of the PMC for non-ASF-members and non-officers.
get '/json/historical-comments' do
  user = env.respond_to?(:user) && ASF::Person.find(env.user)
  comments = HistoricalComments.comments

  unless !user or user.asf_member? or ASF.pmc_chairs.include? user
    status 206 # Partial Content
    committees = user.committees.map(&:display_name)
    comments = comments.select do |project, _list|
      committees.include? project
    end
  end

  _json comments.to_h
end

# draft minutes
get '/text/draft/:file' do |file|
  agenda = "board_agenda_#{file.gsub('-', '_')}.txt"
  minutes = AGENDA_WORK + '/' +
    agenda.sub('_agenda_', '_minutes_').sub('.txt', '.yml')

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
  # extract time and date for next meeting, month of previous meeting
  @meeting = ASF::Board.nextMeeting
  localtime = ASF::Board::TIMEZONE.utc_to_local(@meeting)
  @tzlink = ASF::Board.tzlink(localtime)
  zone = ASF::Board::TIMEZONE.name
  @start_time = localtime.strftime('%H:%M') + ' ' + zone
  duration = 1.hours
  @adjournment = (localtime + duration).strftime('%H:%M') + ' ' + zone
  @prev_month = @meeting.to_date.prev_month.strftime('%B')

  # retrieve latest committee info
  # TODO: this is the workspace copy -- should it be using the copy from SVN instead?
  cinfo = File.join(ASF::SVN['board'], 'committee-info.txt')
  info = ASF::SVN.getInfo(cinfo, env.user, env.password)
  contents = ASF::SVN.svn('cat', cinfo, {env: env})
  ASF::Committee.load_committee_info(contents, info)

  # extract committees expected to report 'next month'
  next_month = contents[/Next month.*?\n\n/m].chomp
  @next_month = next_month[/(.*#.*\n)+/] || ''

  # get potential actions
  actions = JSON.parse(Wunderbar::JsonBuilder.new({}).instance_eval(
    File.read("#{settings.views}/actions/potential-actions.json.rb"),
  ).target!, symbolize_names: true)[:actions]

  # Get directors, list of pmcs due to report, and shepherds
  @directors = ASF::Board.directors
  @pmcs = ASF::Board.reporting(@meeting)
  @owner = ASF::Board::ShepherdStream.new(actions)

  # Get list of unpublished and unapproved minutes
  draft = YAML.load_file(Dir["#{AGENDA_WORK}/board_minutes*.yml"].max)
  @minutes = dir("board_agenda_*.txt").
    map {|file| Date.parse(file[/\d[_\d]+/].gsub('_', '-'))}.
    reject {|date| date >= @meeting.to_date}.
    reject {|date| draft[date.strftime('%B %d, %Y')] == 'approved'}.
    sort

  template = File.join(ASF::SVN['foundation_board'], 'templates', 'board_agenda.erb')
  @disabled = dir("board_agenda_*.txt").
    include? @meeting.strftime("board_agenda_%Y_%m_%d.txt")

  begin
    @agenda = Erubis::Eruby.new(IO.read(template)).result(binding)
  rescue => error
    status 500
    STDERR.puts error
    return "error in #{template} in: #{error}"
  end

  @cssmtime = File.mtime('public/stylesheets/app.css').to_i
  _html :new
end

# post a new agenda
post %r{/(\d\d\d\d-\d\d-\d\d)/} do |date|
  return [503, UNAVAILABLE] if UNAVAILABLE

  boardurl = ASF::SVN.svnurl('foundation_board')
  agenda = "board_agenda_#{date.gsub('-', '_')}.txt"

  contents = params[:agenda].gsub("\r\n", "\n")

  Dir.mktmpdir do |dir|

    ASF::SVN.svn('checkout', [boardurl, dir], {depth: 'empty', env: env})

    agendapath = File.join(dir, agenda)
    File.write agendapath, contents
    ASF::SVN.svn('add', agendapath)

    currentpath = File.join(dir, 'current.txt')
    ASF::SVN.svn('update', currentpath, {env: env})

    File.unlink currentpath
    File.symlink agenda, currentpath

    ASF::SVN.svn('commit', [agendapath, currentpath], {msg: "Post #{date} agenda", env: env})
    Agenda.update_cache agenda, agendapath, contents, false
  end

  redirect to("/#{date}/")
end
