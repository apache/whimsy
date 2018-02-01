#
# Server side setup for whimsy/project
#

require 'whimsy/asf'

require 'wunderbar/sinatra'
require 'wunderbar/vue'
require 'wunderbar/bootstrap/theme'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'
require 'json'
require 'mail'

ASF::Mail.configure

disable :logging # suppress log of requests to stderr/error.log

helpers do
  def projectsForUser(userName)
    pmcs = ASF::Committee.pmcs.map(&:name).sort
    ppmcs =ASF::Podling.list
      .select {|podling| podling.status == 'current'}
      .map(&:name).sort
    user = ASF::Person.find(userName)
    committees = user.committees.map(&:name)
    pmcs.select! {|pmc| committees.include?(pmc)}
    ppmcs.select! {|ppmc|
      committees.include?('incubator') |
      committees.include?(ppmc)}
    # mailList is a hash where the key is the name of the PMC/PPMC and
    # the value is the name of the mail list for the committee
    mailList = pmcs.map{|pmc| [pmc, ASF::Committee.find(pmc).mail_list]}.to_h.
      merge(ppmcs.map{|ppmc| [ppmc, ASF::Podling.find(ppmc).mail_list]}.to_h)
    hash = {
      'pmcs' => pmcs,
      'ppmcs' => ppmcs,
      'pmcmail' => mailList
    }
  end
  def loadProgress(token)
    if @token
      # read the file corresponging to the token
      # the file name is '/srv/<token>.json
      @filename = '/srv/icla/' + token + '.json'
      begin
        @progress = JSON.parse(File.read(@filename))
      rescue SystemCallError => e
        @progress = {
          phase: 'error', errorMessage: e.message, errorCode: e.errno
        }
      rescue JSON::ParserError => e
        @progress = {
          phase: 'error', errorMessage: e.message, errorCode: 999
        }
      end
    end
  end
  def getMember(userId)
    user = ASF::Person.find(userId)
    mockId = params['mock']
    if ASF::Person[mockId] != nil
      # if mock is set, set member to mock value
      return mockId
    else
     return userId
    end
  end
end

@phase = ''
@progress = ''
@extra = ''
#
# Sinatra routes
#


get '/' do
  @token = params['token']
  @mock = params['mock']
  @extra = @mock ? "&mock=" + @mock : ''
  loadProgress(@token) if @token
  @phase = @progress['phase'] if @progress
  if @phase == 'discuss'
    redirect to("/discuss?token=" + @token + @extra)
  elsif @phase == 'vote'
    redirect to("/vote?token=" + @token + @extra)
  else
    redirect to("/invite")
  end
end

get '/invite' do
  @view = 'invite'


  # server data sent to client
  @user = env.user
  @member = getMember(@user)
  # get a complete list of PMC and PPMC names and mail lists
  projects = projectsForUser(@member)
  @pmcs = projects['pmcs']
  @ppmcs = projects['ppmcs']
  @pmc_mail = projects['pmcmail']

  @cssmtime = File.mtime('public/css/icla.css').to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i

  # render the HTML for the application
  _html :app
end

get '/discuss' do
  @view = 'discuss'

  # server data sent to client
  @debug = params['debug']
  @user = env.user
  @member = getMember(@user)
  @token = params['token']
  loadProgress(@token) if @token

  # not needed for this form but required for other forms
  @pmcs = []
  @ppmcs = []
  @pmc_mail = {}

  @cssmtime = File.mtime('public/css/icla.css').to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i

  _html :app
end

get '/vote' do
  @view = 'vote'

# server data sent to client
  @debug = params['debug']
  @user = env.user
  @member = getMember(@user)
  @token = params['token']
  loadProgress(@token) if @token

  # not needed for this form but required for other forms
  @pmcs = []
  @ppmcs = []
  @pmc_mail = {}

  @cssmtime = File.mtime('public/css/icla.css').to_i
  @appmtime = Wunderbar::Asset.convert("#{settings.views}/app.js.rb").mtime.to_i

  _html :app
end

get '/form' do
  @view = 'interview'
  _html :app
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end
