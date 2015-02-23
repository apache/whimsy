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
  FOUNDATION_BOARD = 'test/work/board'
  MINUTES_WORK = 'test/work/data'
else
  FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
  MINUTES_WORK = '/var/tools/data'
end

get '/' do
  agenda = Dir.chdir(FOUNDATION_BOARD) {Dir['board_agenda_*.txt'].sort.last}
  redirect to("/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/")
end

get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  Dir.chdir(FOUNDATION_BOARD) {@agendas = Dir['board_agenda_*.txt'].sort}
  Dir.chdir(FOUNDATION_BOARD) {@drafts = Dir['board_minutes_*.txt'].sort}
  @base = env['PATH_INFO'].chomp(path).untaint
  @agenda = "board_agenda_#{date.gsub('-','_')}.txt"

  if AGENDA_CACHE[@agenda][:mtime] == 0
    Dir.chdir(FOUNDATION_BOARD) do
      AGENDA_CACHE.parse(@agenda, true)
    end
  end

  @parsed = AGENDA_CACHE[@agenda][:parsed]
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
  self[file] = {
    mtime: quick ? -1 : File.mtime(file),
    parsed: ASF::Board::Agenda.parse(File.read(file), quick)
  }
end

get %r{(\d\d\d\d-\d\d-\d\d).json} do |file|
  file = "board_agenda_#{file.gsub('-','_')}.txt"
  _json do
    Dir.chdir(FOUNDATION_BOARD) do
      if Dir['board_agenda_*.txt'].include? file
        file = file.dup.untaint
        if AGENDA_CACHE[file][:mtime] != File.mtime(file)
          AGENDA_CACHE.parse file
        end
        last_modified AGENDA_CACHE[file][:mtime]
        _! AGENDA_CACHE[file][:parsed]
      end
    end
  end
end

# aggressively cache minutes
MINUTE_CACHE = Hash.new(mtime: 0)
def MINUTE_CACHE.parse(file)
  self[file] = {
    mtime: File.mtime(file),
    parsed: YAML.load_file(file)
  }
end

get '/json/minutes/:file' do |file|
  file = "board_minutes_#{file.gsub('-','_')}.yml".untaint
  _json do
    Dir.chdir(MINUTES_WORK) do
      if Dir['board_minutes_*.yml'].include? file
        last_modified File.mtime(file)
        _! MINUTE_CACHE.parse(file)[:parsed]
      end
    end
  end
end

get '/text/minutes/:file' do |file|
  file = "board_minutes_#{file.gsub('-','_')}.txt".untaint
  _text do
    Dir.chdir(FOUNDATION_BOARD) do
      if Dir['board_minutes_*.txt'].include? file
        last_modified File.mtime(file)
        _ File.read(file)
      else
        halt 404
      end
    end
  end
end

get '/text/draft/:file' do |file|
  agenda = "board_agenda_#{file.gsub('-','_')}.txt".untaint
  minutes = MINUTES_WORK + '/' + 
    agenda.sub('_agenda_','_minutes_').sub('.txt','.yml')

  _text do
    Dir.chdir(FOUNDATION_BOARD) do
      if Dir['board_agenda_*.txt'].include?(agenda) and File.exist? minutes
        _ Minutes.draft(agenda, minutes)
      else
        halt 404
      end
    end
  end
end
