#!/usr/bin/ruby

#
# Server side router/controllers
#

require 'whimsy/asf'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/react'
require 'wunderbar/underscore'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require_relative 'banner'
require_relative 'models'

get '/' do
  @committers = ASF::Person.list
  @committees = ASF::Committee.list
  _html :index
end

get '/committer/' do
  _html :committers
end

get '/committee/' do
  @members = ASF::Member.list.keys
  @committees = ASF::Committee.list
  _html :committees
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
  _json Committee.serialize(name)
end

get '/committee/:name' do |name|
  @auth = Auth.info(env)
  @committee = Committee.serialize(name)
  _html :committee
end

get '/committer/:name.json' do |name|
  _json Committer.serialize(name)
end

get '/committer/:name' do |name|
  @committer = Committer.serialize(name)
  _html :committer
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end

# attic issues
get '/attic/issues.json' do
  _json Attic.issues
end
