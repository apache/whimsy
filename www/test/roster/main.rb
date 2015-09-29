#!/usr/bin/ruby

#
# Server side router/controllers
#

require 'whimsy/asf'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/react'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require_relative 'models'

get '/committers.json' do
  # bulk loading the mail information makes things go faster
  mail = Hash[ASF::Mail.list.group_by(&:last).
    map {|person, list| [person, list.map(&:first)]}]

  # return a list of people, their public-names, and email addresses
  _json Hash[ASF::Person.list.map {|person|
    [person.id, {name: person.public_name, mail: mail[person]}]
  }]
end

get '/committee/:name.json' do |name|
  _json Committee.serialize(name)
end

get '/committee/:name' do |name|
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
