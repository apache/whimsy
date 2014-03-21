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
require 'wunderbar/jquery/filter'
require 'ruby2js/filter/functions'

require 'yaml'
require 'net/http'
require_relative 'helpers/string'

svn = ASF::SVN['private/foundation/board']
MINUTES_WORK = '/var/tools/data'

require_relative 'model/pending'

set :views, File.dirname(__FILE__)

get '/' do
  agenda = Dir.chdir(svn) {Dir['board_agenda_*.txt'].sort.last}
  puts("/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/")
  redirect to("/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/")
end

get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  Dir.chdir(svn) {@agendas = Dir['board_agenda_*.txt'].sort}
  @base = env['REQUEST_URI'].chomp(path)
  @agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  _html :'views/main'
end

get '/js/:file.js' do
  _js :"js/#{params[:file]}"
end

get '/partials/:file.html' do
  _html :"partials/#{params[:file]}"
end

get '/json/jira' do
  _json :'/json/jira'
end

get '/json/pending' do
  _json do
    _! Pending.get(env.user)
  end
end

AGENDA_CACHE = Hash.new(mtime: 0)
get '/json/:file' do |file|
  _json do
    Dir.chdir(svn) do
      if Dir['board_agenda_*.txt'].include? file
        if AGENDA_CACHE[file][:mtime] != File.mtime(file)
          AGENDA_CACHE[file] = {
            mtime: File.mtime(file),
            parsed: ASF::Board::Agenda.parse(File.read(file.dup.untaint))
          }
        end
        _! AGENDA_CACHE[file][:parsed]
      end
    end
  end
end

post '/json/:file' do
  _json :"json/#{params[:file]}"
end
