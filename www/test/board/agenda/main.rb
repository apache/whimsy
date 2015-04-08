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
require 'shellwords'

require_relative './routes'
require_relative './models/pending'
require_relative './helpers/string'

# determine where relevant data can be found
if ENV['RACK_ENV'] == 'test'
  FOUNDATION_BOARD = File.expand_path('test/work/board').untaint
  AGENDA_WORK = File.expand_path('test/work/data').untaint
else
  FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
  AGENDA_WORK = ASF::Config.get(:agenda_work) || '/var/tools/data'
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

# aggressively cache agenda
class AgendaCache
  @@mutex = Mutex.new
  @@cache = Hash.new(mtime: 0)

  def self.[](file)
    @@cache[file]
  end

  def self.parse(file, mode)
    # for quick mode, anything will do
    mode = :quick if ENV['RACK_ENV'] == 'test'
    return self[file][:parsed] if mode == :quick and self[file][:mtime] != 0

    file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\Z/
    path = File.expand_path(file, FOUNDATION_BOARD).untaint
    
    return unless File.exist? path

    if self[file][:mtime] != File.mtime(path)
      @@mutex.synchronize do
        if self[file][:mtime] != File.mtime(path)
          @@cache[file] = {
            mtime: mode == :quick ? -1 : File.mtime(path),
            parsed: ASF::Board::Agenda.parse(File.read(path), mode == :quick)
          }
        end
      end

      # do a full parse in the background if a quick parse was done
      if @@cache[file][:mtime] == -1
        Thread.new do
          self.update(file, nil)
          parse(file, :full)
        end
      end
    end

    self[file][:parsed]
  end

  # update agenda file in SVN
  def self.update(file, message, &block)
    # Create a temporary work directory
    dir = Dir.mktmpdir

    #extract context from block
    _, env = eval('[_, env]', block.binding)

    auth = [[]]
    if env.password
      auth = [['--username', env.user, '--password', env.password]]
    end

    @@mutex.synchronize do
      # check out empty directory
      board = `svn info #{FOUNDATION_BOARD}`[/URL: (.*)/, 1]
      _.system ['svn', 'checkout', auth, '--depth', 'empty', board, dir]

      # build and untaint path
      file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\Z/
      path = File.join(dir, file)

      # update the file in question
      _.system ['svn', 'update', auth, path]

      # invoke block, passing it the current contents of the file
      if block and message
        input = IO.read(path)
        output = yield input.dup

        # if the output differs, update and commit the file in question
        if output != input
          IO.write(path, output)
          _.system ['svn', 'commit', auth, path, '-m', message]
        end
      end

      # update the file in question; update output if mtime changed
      # (it may not: during testing, commits are prevented)
      path = File.join(FOUNDATION_BOARD, file)
      mtime = File.mtime(path) if output
      _.system ['svn', 'update', auth, path]
      output = IO.read(path) if mtime != File.mtime(path)

      # reparse the file
      @@cache[file] = {
        mtime: File.mtime(path),
        parsed: ASF::Board::Agenda.parse(output, ENV['RACK_ENV'] == 'test')
      }

      # return the result
      _.method_missing(:_agenda, @@cache[file][:parsed])
    end

  ensure
    FileUtils.rm_rf dir
  end
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
