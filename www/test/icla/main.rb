#
# Server side setup
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

  # get a complete list of PMCs
  @pmcs = ASF::Committee.pmcs.map(&:name).sort

  # for non ASF members, limit PMCs to ones for which the user is either a
  # member of the PMC or is a committer.
  user = ASF::Person.find(env.user)
  unless user.asf_member?
    committees = user.committees.map(&:name)
    groups = user.groups.map(&:name)
    @pmcs.select! {|pmc| committees.include?(pmc) or groups.include?(pmc)}
  end

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
