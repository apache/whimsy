#!/usr/bin/ruby

# while under development, use tip versions of wunderbar and ruby2js
$:.unshift '/home/rubys/git/wunderbar/lib'
$:.unshift '/home/rubys/git/ruby2js/lib'

#
# Server side router/controllers
#

require '/var/tools/asf'
require '/var/tools/asf/agenda'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/angularjs/route'
require 'ruby2js/filter/functions'

svn = ASF::SVN['private/foundation/board']
MINUTES_WORK = '/var/tools/data'

require_relative 'model/pending'

set :views, File.dirname(__FILE__)

get '/' do
  Dir.chdir(svn) {@agendas = Dir['board_agenda_*.txt'].sort}
  @agenda = @agendas.last
  _html :'views/index'
end

get '/board_agenda_:date.txt' do
  Dir.chdir(svn) {@agendas = Dir['board_agenda_*.txt'].sort}
  @agenda = "board_agenda_#{params[:date]}.txt"
  _html :'views/index'
end

get '/js/:file.js' do
  _js :"js/#{params[:file]}"
end

get '/partials/:file.html' do
  _html :"partials/#{params[:file]}"
end

get '/json/:file' do
  _json do
    Dir.chdir(svn) do
      if Dir['board_agenda_*.txt'].include? params[:file]
        _! ASF::Board::Agenda.parse(File.read(params[:file].dup.untaint))
      end
    end
  end
end

post '/json/:file' do
  _json :"json/#{params[:file]}"
end
