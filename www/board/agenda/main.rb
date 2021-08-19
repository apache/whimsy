#!/usr/bin/env ruby

#
# Server side setup
#

require 'whimsy/asf/agenda'
require 'whimsy/asf/board'

require 'wunderbar/sinatra'
require 'wunderbar/vue'
require 'wunderbar/bootstrap/theme'
require 'ruby2js/es2020'
require 'ruby2js/strict'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require 'listen'
require 'yaml'
require 'net/http'
require 'shellwords'
require 'mail'
require 'open-uri'
require 'erubis'
require 'tzinfo'
require 'active_support'
require 'active_support/time'
require 'mustache'

unless ENV['RACK_ENV'] == 'development'
  disable :logging # suppress log of requests to stderr/error.log
end

# needs to match all agendas and minutes
BOARD_REGEX = %r{\Aboard_\w+_[-\d_]+\.txt\z}

# determine where relevant data can be found
if ENV['RACK_ENV'] == 'test'
  FOUNDATION_BOARD = File.expand_path('test/work/board')
  AGENDA_WORK = File.expand_path('test/work/data')
  STDERR.puts "* SVN board  : #{FOUNDATION_BOARD}"
  STDERR.puts "* Agenda work: #{AGENDA_WORK}"
else
  FOUNDATION_BOARD = ASF::SVN['foundation_board']
  AGENDA_WORK = ASF::Config.get(:agenda_work) || '/srv/agenda'
  # STDERR.puts "* SVN board  : #{FOUNDATION_BOARD}"
  # STDERR.puts "* Agenda work: #{AGENDA_WORK}"
end

FileUtils.mkdir_p AGENDA_WORK unless Dir.exist? AGENDA_WORK

require_relative './routes'
require_relative './models/pending'
require_relative './models/agenda'
require_relative './models/minutes'
require_relative './models/comments'
require_relative './models/reporter'
require_relative './helpers/string'
require_relative './helpers/integer'
require_relative './daemon/session'
require_relative './daemon/events'

# if AGENDA_WORK doesn't exist yet, make it
unless Dir.exist? AGENDA_WORK
  require 'fileutils'
  FileUtils.mkdir_p AGENDA_WORK
end

# get a directory listing given a pattern and a base directory
def dir(pattern, base=FOUNDATION_BOARD)
  Dir[File.join(base, pattern)].map {|name| File.basename name}
end

def validate_board_file(name)
  raise ArgumentError, "Invalid filename #{name}" unless name =~ BOARD_REGEX
end
