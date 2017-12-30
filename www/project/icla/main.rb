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

  # render the HTML for the application
  _html :app
end

get '/discuss' do
  @view = 'discuss'

  # get a complete list of PMC and PPMC names and mail lists
  projects = projectsForUser(env.user)

  # server data sent to client
  @pmcs = projects['pmcs']
  @ppmcs = projects['ppmcs']
  @pmc_mail = projects['pmcmail']

  _html :app
end

get '/vote' do
  @view = 'vote'

  # get a complete list of PMC and PPMC names and mail lists
  projects = projectsForUser(env.user)

  # server data sent to client
  @pmcs = projects['pmcs']
  @ppmcs = projects['ppmcs']
  @pmc_mail = projects['pmcmail']

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
