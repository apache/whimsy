#!/usr/bin/ruby

#
# Server side router/controllers
#

require 'whimsy/asf/agenda'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/react'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require 'yaml'

if ENV['RACK_ENV'] == 'test'
  FOUNDATION_BOARD = File.expand_path('test/work/board').untaint
  MINUTES_WORK = File.expand_path('test/work/data').untaint
else
  FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
  MINUTES_WORK = '/var/tools/data'
end

def dir(pattern, base=FOUNDATION_BOARD)
  Dir[File.join(base, pattern)].map {|name| File.basename name}
end

get '/' do
  agenda = dir('board_agenda_*.txt').sort.last
  redirect to("/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/")
end

get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  @agendas = dir('board_agenda_*.txt').sort
  @drafts = dir('board_minutes_*.txt').sort
  @base = env['PATH_INFO'].chomp(path).untaint
  @path = path
  @query = params['q']
  @agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless File.exist? File.join(FOUNDATION_BOARD, @agenda)

  if AGENDA_CACHE[@agenda][:mtime] == 0
    AGENDA_CACHE.parse(@agenda, true)
  end

  @parsed = AGENDA_CACHE[@agenda][:parsed]
  @etag = AGENDA_CACHE[@agenda][:etag]
  @etag = nil unless AGENDA_CACHE[@agenda][:mtime].to_i > 0

  _html :'main'
end

get '/json/jira' do
  _json :'jira'
end

get '/json/pending' do
  _json do
    Pending.get(env.user)
  end
end

get '/json/secretary_todos/:file' do
  _json :'json/todos'
end

post '/json/:file' do
  _json :"json/#{params[:file]}"
end

# aggressively cache agenda
AGENDA_CACHE = Hash.new(mtime: 0)
def AGENDA_CACHE.parse(file, quick=false)
  path = File.expand_path(file, FOUNDATION_BOARD).untaint
  self[file] = {
    mtime: quick ? -1 : File.mtime(path),
    parsed: ASF::Board::Agenda.parse(File.read(path), quick)
  }
end

get %r{(\d\d\d\d-\d\d-\d\d).json} do |file|
  file = "board_agenda_#{file.gsub('-','_')}.txt"
  path = File.expand_path(file, FOUNDATION_BOARD).untaint
  pass unless File.exist? path

  response = _json do
    file = file.dup.untaint

    if AGENDA_CACHE[file][:mtime] != File.mtime(path)
      AGENDA_CACHE.parse file
    end

    last_modified AGENDA_CACHE[file][:mtime]
    AGENDA_CACHE[file][:parsed]
  end

  AGENDA_CACHE[file][:etag] = headers['ETag']
  response
end

# aggressively cache minutes
MINUTE_CACHE = Hash.new(mtime: 0)
def MINUTE_CACHE.parse(file)
  path = File.expand_path(file, MINUTES_WORK).untaint
  self[file] = {
    mtime: File.mtime(path),
    parsed: YAML.load_file(path)
  }
end

get '/json/minutes/:file' do |file|
  file = "board_minutes_#{file.gsub('-','_')}.yml"
  path = File.expand_path(file, MINUTES_WORK).untaint
  pass unless File.exits? path

  _json do
    last_modified File.mtime(path)
    MINUTE_CACHE.parse(file)[:parsed]
  end
end

get '/text/minutes/:file' do |file|
  file = "board_minutes_#{file.gsub('-','_')}.txt".untaint
  pass unless dir('board_minutes_*.txt').include? file
  path = File.expand_path(file, FOUNDATION_BOARD).untaint

  _text do
    last_modified File.mtime(path)
    File.read(path)
  end
end

get '/text/draft/:file' do |file|
  agenda = "board_agenda_#{file.gsub('-','_')}.txt".untaint
  minutes = MINUTES_WORK + '/' + 
    agenda.sub('_agenda_','_minutes_').sub('.txt','.yml')
  pass unless dir('board_agenda_*.txt').include?(agenda) and File.exist? minutes

  _text do
    Minutes.draft(agenda, minutes)
  end
end
