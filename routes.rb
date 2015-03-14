#
# Server side Sinatra routes
#

# redirect root to latest agenda
get '/' do
  agenda = dir('board_agenda_*.txt').sort.last
  redirect to("/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/")
end

# all agenda pages
get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless AGENDA_CACHE.parse agenda, :quick

  @base = (env['SCRIPT_URL']||env['PATH_INFO']).chomp(path).untaint

  if ENV['RACK_ENV'] == 'test'
    userid = 'test'
    username = 'Joe Tester'
  else
    require 'etc'
    userid = env['REMOTE_USER'] || Etc.getlogin
    username = Etc.getpwnam(userid)[4].split(',').first
  end

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: Pending.get(userid),
    username: username,
    initials: username.gsub(/[^A-Z]/, '').downcase
  }

  @page = {
    date: date,
    path: path,
    query: params['q'],
    agenda: agenda,
    parsed: AGENDA_CACHE[agenda][:parsed],
    etag: AGENDA_CACHE[agenda][:etag]
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
  pass unless AGENDA_CACHE.parse file, :full

  begin
    _json do
      last_modified AGENDA_CACHE[file][:mtime]
      AGENDA_CACHE[file][:parsed]
    end
  ensure
    AGENDA_CACHE[file][:etag] = headers['ETag']
  end
end
