# Aggressively cache agendas.
#
# Most of the heavy lifting is done by ASF::Board::Agenda in the whimsy-asf
# gem.  This class is mainly focused on caching the results.
#
class Agenda
  @@mutex = Mutex.new
  @@cache = Hash.new(mtime: 0)

  def self.[](file)
    @@cache[file]
  end

  def self.update_cache(file, path, contents, quick)
    parsed = ASF::Board::Agenda.parse(contents, quick)
    @@cache[file] = {mtime: (quick ? -1 : File.mtime(path)), parsed: parsed}
    Events.post type: :agenda, file: file unless quick
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
          self.update_cache(file, path, File.read(path), mode == :quick)
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
      file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\Z/

      # capture current version of the file
      path = File.join(FOUNDATION_BOARD, file)
      baseline = File.read(path) if @@cache[file][:mtime] == File.mtime(path)

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
          _.system ['svn', 'commit', auth, path, '-m', message]
        end
      end

      # update the file in question; update output if mtime changed
      # (it may not: during testing, commits are prevented)
      path = File.join(FOUNDATION_BOARD, file)
      mtime = File.mtime(path) if output
      _.system ['svn', 'update', auth, path]
      output = IO.read(path) if mtime != File.mtime(path)

      # reparse the file if the output changed
      if output != baseline or mtime != File.mtime(path)
        self.update_cache(file, path, output, ENV['RACK_ENV'] == 'test')
      end

      # return the result
      _.method_missing(:_agenda, @@cache[file][:parsed])
    end

  ensure
    FileUtils.rm_rf dir
  end
end
