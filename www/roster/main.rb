#!/usr/bin/ruby

#
# Server side router/controllers
#

require 'whimsy/asf'
require 'whimsy/asf/podlings'

require 'mail'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/react'
require 'wunderbar/underscore'
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
    @podlings = ASF::Podlings.new.to_h.values
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

post '/committer/:name' do |name|
  @userid = name
  _json :'/actions/committer'
end

get '/group/:name.json' do |name|
  _json Group.serialize(name)
end

get '/group/:name' do |name|
  @group = Group.serialize(name)
  pass unless @group
  _html :group
end

get '/group/' do
  @groups = Group.list
  @podlings = ASF::Podlings.new.to_h
  _html :groups
end

# member list
get '/members' do
  _html :members
end

get '/members.json' do
  _json Hash[ASF.members.map {|person| [person.id, person.public_name]}.sort]
end

# member list
get '/podlings' do
  attic = ASF::SVN['asf/attic/site/xdocs/projects']
  @attic = Dir["#{attic}/*.xml"].map {|file| File.basename(file, '.xml')}
  @committees = ASF::Committee.list.map(&:id)
  @podlings = ASF::Podlings.new.to_a.map {|id, hash| hash.merge id: id}

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
