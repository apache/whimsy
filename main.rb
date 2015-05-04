#!/usr/bin/ruby

#
# Server side setup
#

require 'whimsy/asf/agenda'

require 'wunderbar/sinatra'
require 'wunderbar/react'
require 'wunderbar/bootstrap/theme'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require 'yaml'
require 'thread'
require 'net/http'
require 'shellwords'

require_relative './routes'
require_relative './models/pending'
require_relative './models/events'
require_relative './models/agenda'
require_relative './helpers/string'

# determine where relevant data can be found
if ENV['RACK_ENV'] == 'test'
  FOUNDATION_BOARD = File.expand_path('test/work/board').untaint
  AGENDA_WORK = File.expand_path('test/work/data').untaint
else
  FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
  AGENDA_WORK = ASF::Config.get(:agenda_work).untaint || '/var/tools/data'
  STDERR.puts "* SVN board  : #{FOUNDATION_BOARD}"
  STDERR.puts "* Agenda work: #{AGENDA_WORK}"
end

# if AGENDA_WORK doesn't exist yet, make it
if not Dir.exist? AGENDA_WORK
  require 'fileutils'
  FileUtils.mkdir_p AGENDA_WORK
end

# get a directory listing given a pattern and a base directory
def dir(pattern, base=FOUNDATION_BOARD)
  Dir[File.join(base, pattern)].map {|name| File.basename name}
end

# aggressively cache minutes
MINUTE_CACHE = Hash.new(mtime: 0)
def MINUTE_CACHE.parse(file)
  path = File.expand_path(file, AGENDA_WORK).untaint
  self[file] = {
    mtime: File.mtime(path),
    parsed: YAML.load_file(path)
  }
end
