##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

# Aggressively cache agendas.
#
# Most of the heavy lifting is done by ASF::Board::Agenda in the whimsy-asf
# gem.  This class is mainly focused on caching the results.
#
# This code also maintains a "working copy" of agendas when updates are
# made that may not yet be reflected in the local svn checkout.
#

require 'digest'

class Agenda
  CACHE = File.join(AGENDA_WORK, 'cache')
  FileUtils.mkdir_p CACHE
  @@cache = Hash.new {|hash, key| hash[key] = {mtime: 0}}

  # for debug purposes
  def self.cache
    @@cache
  end

  # flush cache of files made with previous versions of the library
  libmtime = ASF::library_mtime
  Dir["#{CACHE}/*.yml"].each do |cache|
    File.unlink(cache) if File.mtime(cache) < libmtime
  end

  # fetch parsed agenda from in memory cache if up to date, otherwise
  # fall back to disk.
  def self.[](file)
    path = File.join(CACHE, file.sub(/\.txt$/, '.yml'))
    path.untaint if file =~ /^board_agenda_\d+_\d+_\d+\.txt$/
    data = @@cache[file]

    if File.exist?(path) and File.mtime(path) != data[:mtime]
      File.open(path) do |fh|
        fh.flock(File::LOCK_SH)
        data = YAML.load(fh.read)
      end
      @@cache[file] = data
    end

    data
  end

  # update both in memory and disk caches with new parsed agenda
  def self.[]=(file, data)
    path = File.join(CACHE, file.sub(/\.txt$/, '.yml'))
    path.untaint if file =~ /^board_agenda_\d+_\d+_\d+\.txt$/

    File.open(path, File::RDWR|File::CREAT, 0644) do |fh|
      fh.flock(File::LOCK_EX)
      fh.write(YAML.dump(data))
      fh.flush
      fh.truncate(fh.pos)
      if data[:mtime].instance_of? Time
        File.utime data[:mtime], data[:mtime], path
      end
    end

    @@cache[file] = data
    data
  end

  def self.update_cache(file, path, contents, quick)
    update = {
      mtime: (quick ? -1 : File.mtime(path)),
      digest: Digest::SHA256.base64digest(contents)
    }

    # update cache if there wasn't a previous entry, the digest changed,
    # or the previous entry was the result of a 'quick' parse.
    current = Agenda[file]
    if not current or current[:digest] != update[:digest] or
      current[:mtime].to_i < update[:mtime].to_i
    then
      if current and current[:digest] == update[:digest] and
        current[:mtime].to_i > 0
      then
        update[:parsed] = current[:parsed]
      else
        update[:parsed] = ASF::Board::Agenda.parse(contents, quick)
      end

      Agenda[file] = update
    end
  end

  def self.uptodate(file)
    path = File.expand_path(file, FOUNDATION_BOARD).untaint
    return false unless File.exist? path
    return Agenda[file][:mtime] == File.mtime(path)
  end

  def self.parse(file, mode)
    # for quick mode, anything will do
    mode = :quick if ENV['RACK_ENV'] == 'test'
    return Agenda[file][:parsed] if mode == :quick and Agenda[file][:mtime] != 0

    file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\z/
    path = File.expand_path(file, FOUNDATION_BOARD).untaint
    
    return Agenda[file][:parsed] unless File.exist? path

    # Does the working copy have more recent data?
    working_copy = File.join(AGENDA_WORK, file)
    if File.size?(working_copy) and File.mtime(working_copy) > File.mtime(path)
      path = working_copy
    end

    if Agenda[file][:mtime] != File.mtime(path)
      File.open(working_copy, File::RDWR|File::CREAT, 0644) do |work_file|
        work_file.flock(File::LOCK_EX)
        if Agenda[file][:mtime] != File.mtime(path)
          self.update_cache(file, path, File.read(path), mode == :quick)
        end
      end

      # do a full parse in the background if a quick parse was done
      if Agenda[file][:mtime] == -1
        Thread.new do
          self.update(file, nil)
          parse(file, :full)
        end
      end
    end

    Agenda[file][:parsed]
  end

  # update agenda file in SVN
  def self.update(file, message, retries=20, &block)
    return unless block
    commit_rc = 0

    # Create a temporary work directory
    dir = Dir.mktmpdir

    #extract context from block
    _, env = eval('[_, env]', block.binding)

    auth = [[]]
    if env.password
      auth = [['--username', env.user, '--password', env.password]]
    end

    file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\z/

    working_copy = File.join(AGENDA_WORK, file)

    File.open(working_copy, File::RDWR|File::CREAT, 0644) do |work_file|
      work_file.flock(File::LOCK_EX)

      # capture current version of the file
      path = File.join(FOUNDATION_BOARD, file)
      baseline = File.read(path) if Agenda[file][:mtime] == File.mtime(path)

      # check out empty directory
      board = `svn info #{FOUNDATION_BOARD}`[/URL: (.*)/, 1]
      _.system ['svn', 'checkout', auth, '--depth', 'empty', board, dir]

      # update the file in question
      path = File.join(dir, file)
      _.system ['svn', 'update', auth, path]

      # invoke block, passing it the current contents of the file
      if block and message
        input = IO.read(path)
        output = yield input.dup

        # if the output differs, update and commit the file in question
        if output != input
          IO.write(path, output)
          commit_rc = _.system ['svn', 'commit', auth, path, '-m', message]
        end
      else
        output = IO.read(path)
      end

      if commit_rc == 0
        # update the work file, and optionally the cache, if successful
        work_file.rewind

        if output != baseline
          # update the cache if the file has changed
          self.update_cache(file, path, output, ENV['RACK_ENV'] == 'test')
          work_file.write(output)
          work_file.flush
        end

        work_file.truncate(work_file.pos)
      else
        # if not successful, retry
        if retries > 0
          work_file.close
          sleep rand(41-retries*2)*0.1 if retries <= 20
          update(file, message, retries-1, &block)
        else
          raise Exception.new("svn commit failed")
        end
      end

      # return the result in the response
      _.method_missing(:_agenda, Agenda[file][:parsed])
      _.method_missing(:_digest, Agenda[file][:digest])
    end

  ensure
    FileUtils.rm_rf dir if dir
  end
end
