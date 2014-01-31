#!/usr/bin/ruby

# while under development, use tip versions of wunderbar and ruby2js
$:.unshift '/home/rubys/git/wunderbar/lib'
$:.unshift '/home/rubys/git/ruby2js/lib'

#
# Server side router/controllers
#

require '/var/tools/asf'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/angularjs/route'
require 'wunderbar/jquery/filter'
require 'ruby2js/filter/functions'

require_relative 'model/ldap'

set :views, File.dirname(__FILE__)

get '/' do
  @base = env['REQUEST_URI']
  _html :'views/main'
end

get %r{/(committer/.*)} do |path|
  @base = env['REQUEST_URI'].chomp(path)
  _html :'views/main'
end

get '/js/:file.js' do
  _js :"js/#{params[:file]}"
end

get '/partials/:file.html' do
  _html :"partials/#{params[:file]}"
end

get '/json/ldap' do
  _json do
    _! ASF::RosterLDAP.get
  end
end

post '/json/:file' do
  _json :"json/#{params[:file]}"
end
