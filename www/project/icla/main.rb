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

#
# Sinatra routes
#

get '/' do
  redirect to('/invite')
end

get '/invite' do
  @view = 'invite'

  # get a complete list of PMC and PPMC names
  @pmcs = ASF::Committee.pmcs.map(&:name).sort
  @ppmcs = ASF::Podling.list
    .select {|podling| podling.status == 'current'}
    .map(&:name).sort

  # allow user to invite contributors for PMCs of which the user is a member,
  # or for podlings if the user is a member of the IPMC.
  user = ASF::Person.find(env.user)
  committees = user.committees.map(&:name)
  ipmc = committees.include?('incubator')
  @pmcs.select! {|pmc| committees.include?(pmc)}
  @ppmcs.select! {|ppmc| committees.include?('incubator') | committees.include?(ppmc)}

  # render the HTML for the application
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
