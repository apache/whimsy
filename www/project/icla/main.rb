#
# Server side setup for whimsy/project
#

require 'whimsy/asf'

require 'wunderbar/sinatra'
require 'wunderbar/vue'
require 'wunderbar/bootstrap/theme'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

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
end

#
# Sinatra routes
#


get '/' do
  redirect to('/invite')
end

get '/invite' do
  @view = 'invite'

  # get a complete list of PMC and PPMC names and mail lists
  projects = projectsForUser(env.user)

  # server data sent to client
  @pmcs = projects['pmcs']
  @ppmcs = projects['ppmcs']
  @pmc_mail = projects['pmcmail']

  @cssmtime = File.mtime('public/css/icla.css')

  # render the HTML for the application
  _html :app
end

get '/discuss' do
  @view = 'discuss'
  @user = env.user

  # get a complete list of PMC and PPMC names and mail lists
  projects = projectsForUser(env.user)

  # server data sent to client
  @token = params['token']
  @debug = params['debug']

  # not needed for this form but required for other forms
  @pmcs = []
  @ppmcs = []
  @pmc_mail = {}

  # mocked for testing
  @proposer = 'shane'
  @contributor = {
    project: 'whimsy',
    name: 'Joe Blow',
    email: 'joe@blow.com'
  }
  @subject = '[DISCUSS] Invite Joe Blow to become committer '\
  'and PMC member for whimsy'
  comment1 = {member: 'sebb', timestamp: '11/30/2017 15:30:00',
    comment: "Seems like a good enough guy"}
  comment2 = {member: 'rubys', timestamp: '12/04/2017 17:20:00',
    comment: "I agree"}
  comment3 = {member: 'clr', timestamp: '12/06/2017 10:14:00',
    comment: "We could do better\nMuch better"}
  @comments = [comment1, comment2, comment3]

  _html :app
end

get '/vote' do
  @view = 'vote'
  @user = env.user

  # server data sent to client
  @token = params['token']
  @debug = params['debug']

  # not needed for this form but required for other forms
  @pmcs = []
  @ppmcs = []
  @pmc_mail = {}

  # mocked for testing
  @proposer = 'shane'
  @contributor = {
    project: 'whimsy',
    name: 'Joe Blow',
    email: 'joe@blow.com'
  }
  @subject = '[VOTE] Invite Joe Blow to become committer '\
  'and PMC member for whimsy'
  comment1 = {member: 'sebb', timestamp: '11/30/2017 15:30:00',
    comment: "Seems like a good enough guy"}
  comment2 = {member: 'rubys', timestamp: '12/04/2017 17:20:00',
    comment: "I agree"}
  comment3 = {member: 'clr', timestamp: '12/06/2017 10:14:00',
    comment: "We could do better\nMuch better"}
  @comments = [comment1, comment2, comment3]

  vote1 = {vote: '+1', member: 'sebb', timestamp: '12/19/2017 15:30:00'}
  vote2 = {vote: '+1', member: 'clr', timestamp: '12/20/2017 14:20:00'}
  vote3 = {vote: '+1', member: 'rubys', timestamp: '12/22/2017 10:33:00'}
  @votes = [vote1, vote2, vote3]

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
