# Aggressively cache agendas.
#
# Most of the heavy lifting is done by ASF::Board::Agenda in the whimsy-asf
# gem.  This class is mainly focused on caching the results.
#
# This code also maintains a "working copy" of agendas when updates are
# made that may not yet be reflected in the local svn checkout.
#
class Agenda
  def self.[](file)
    IPC[file]
  end

  def self.[]=(file, data)
    IPC[file] = data
  end

  def self.update_cache(file, path, contents, quick)
    parsed = ASF::Board::Agenda.parse(contents, quick)
    update = {mtime: (quick ? -1 : File.mtime(path)), parsed: parsed}
    unless IPC[file] and IPC[file] == update
      before = Agenda[file] and Agenda[file][:parsed]

      Agenda[file] = update

      unless quick or before == update[:parsed]
        IPC.post type: :agenda, file: file, mtime: update[:mtime].to_f
      end
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

    file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\Z/
    path = File.expand_path(file, FOUNDATION_BOARD).untaint
    
    return unless File.exist? path

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
    commit_rc = (message ? 999 : 0)

    # Create a temporary work directory
    dir = Dir.mktmpdir

    #extract context from block
    _, env = eval('[_, env]', block.binding)

    auth = [[]]
    if env.password
      auth = [['--username', env.user, '--password', env.password]]
    end

    file.untaint if file =~ /\Aboard_\w+_[\d_]+\.txt\Z/

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
          @@seen[path] = File.mtime(path)
        else
          commit_rc = 0
        end
      else
        output = IO.read(path)
      end

      # update the work file, and optionally the cache, if successful
      if commit_rc == 0
        work_file.rewind

        if output != baseline
          # update the cache if the file has changed
          self.update_cache(file, path, output, ENV['RACK_ENV'] == 'test')
          work_file.write(output)
          work_file.flush
        end

        work_file.truncate(work_file.pos)
      end

      # return the result in the response
      _.method_missing(:_agenda, Agenda[file][:parsed])
    end

  ensure
    FileUtils.rm_rf dir

    unless commit_rc == 0
      if retries > 0
        sleep rand(41-retries*2)*0.1 if retries <= 20
        update(file, message, retries-1, &block)
      else
        raise Exception.new("svn commit failed")
      end
    end
  end

  # listen for changes to agenda files
  @@listener = Listen.to(FOUNDATION_BOARD) do |modified, added, removed|
    modified.each do |path|
      next if File.exist?(path) and @@seen[path] == File.mtime(path)
      file = File.basename(path)
      if file =~ /^board_agenda_[\d_]+.txt$/
        self.update_cache(file, path, File.read(path), false)
      end
    end
  end

  # disable listening when running tests
  @@listener = Struct.new(:start, :stop).new if ENV['RACK_ENV'] == 'test'

  @@seen = {}
  @@listener.start
end
