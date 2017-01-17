#!/usr/bin/env ruby

#
# Server side router/controllers
#

require 'whimsy/asf'

require 'mail'
require 'tmpdir'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/react'
require 'wunderbar/underscore'
require 'wunderbar/markdown'
require 'wunderbar/jquery/stupidtable'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require_relative 'banner'
require_relative 'models'

ASF::Mail.configure

get '/' do
  if env['REQUEST_URI'].end_with? '/'
    @committers = ASF::Person.list
    @committees = ASF::Committee.list
    @members = ASF::Member.list.keys - ASF::Member.status.keys
    @groups = Group.list
    @podlings = ASF::Podling.to_h.values
    _html :index
  else
    redirect to('/')
  end
end

get '/committer/' do
  _html :committers
end

get '/committer' do
  redirect to('/committer/')
end

get '/committee/' do
  @members = ASF::Member.list.keys
  @committees = ASF::Committee.list
  _html :committees
end

get '/committee' do
  redirect to('/committee/')
end

get '/committer/index.json' do
  # bulk loading the mail information makes things go faster
  mail = Hash[ASF::Mail.list.group_by(&:last).
    map {|person, list| [person, list.map(&:first)]}]

  # return a list of people, their public-names, and email addresses
  ASF::Person.list.sort_by(&:id).map {|person|
    result = {id: person.id, name: person.public_name, mail: mail[person]}
    result[:member] = true if person.asf_member?
    result
  }.to_json
end

get '/committee/:name.json' do |name|
  _json Committee.serialize(name, env)
end

get '/committee/:name' do |name|
  @auth = Auth.info(env)
  @committee = Committee.serialize(name, env)
  pass unless @committee
  _html :committee
end

get '/committer/:name.json' do |name|
  _json Committer.serialize(name, env)
end

get '/committer/:name' do |name|
  @auth = Auth.info(env)
  @committer = Committer.serialize(name, env)
  pass unless @committer
  _html :committer
end

post '/committer/:userid/:file' do |name, file|
  _json :"actions/#{params[:file]}"
end

get '/group/:name.json' do |name|
  _json Group.serialize(name)
end

get '/group/:name' do |name|
  @auth = Auth.info(env)
  @group = Group.serialize(name)
  pass unless @group and not @group.empty?
  _html :group
end

get '/group/' do
  @groups = Group.list
  @podlings = ASF::Podling.to_h
  _html :groups
end

# member list
get '/members' do
  _html :members
end

get '/members.json' do
  _json Hash[ASF.members.map {|person| [person.id, person.public_name]}.sort]
end

# active podling list
get '/ppmc/' do
  @projects = ASF::Project.list
  @ppmcs = ASF::Podling.list.select {|podling| podling.status == 'current'}
  _html :ppmcs
end

# individual podling info
get '/ppmc/:name.json' do |name|
  _json PPMC.serialize(name, env)
end

get '/ppmc/:name' do |name|
  @auth = Auth.info(env)
  @ppmc = PPMC.serialize(name, env)
  pass unless @ppmc
  _html :ppmc
end


# complete podling list
get '/podlings' do
  attic = ASF::SVN['asf/attic/site/xdocs/projects']
  @attic = Dir["#{attic}/*.xml"].map {|file| File.basename(file, '.xml')}
  @committees = ASF::Committee.list.map(&:id)
  @podlings = ASF::Podling.list

  _html :podlings
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end

# attic issues
get '/attic/issues.json' do
  _json Attic.issues
end

# overall organization chart
get '/orgchart/' do
  @org = OrgChart.load
  _html :orgchart
end

# individual duties
get '/orgchart/:name' do |name|
  person = ASF::Person.find(env.user)

  unless person.asf_member? or ASF.pmc_chairs.include? person
    halt 401, "Not authorized\n"
  end

  @org = OrgChart.load
  @role = @org[name]
  pass unless @role

  @oversees = @org.select do |role, duties|
    duties['info']['reports-to'].split(/[, ]+/).include? name
  end

  _html :duties
end
