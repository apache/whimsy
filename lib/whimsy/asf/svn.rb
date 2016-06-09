require 'uri'
require 'thread'
require 'open3'
require 'fileutils'
require 'tmpdir'

module ASF

  class SVN
    @base = URI.parse('https://svn.apache.org/repos/')
    @mock = 'file:///var/tools/svnrep/'
    @semaphore = Mutex.new
    @testdata = {}

    def self.repos
      @semaphore.synchronize do
        svn = Array(ASF::Config.get(:svn)).map {|dir| dir.untaint}
        @repos ||= Hash[Dir[*svn].map { |name| 
          next unless Dir.exist? name.untaint
          Dir.chdir name.untaint do
            out, err, status = Open3.capture3('svn', 'info')
            if status.success?
              [out[/URL: (.*)/,1].sub(/^http:/,'https:'), Dir.pwd.untaint]
            end
          end
        }.compact]
      end
    end

    def self.[]=(name, path)
      @testdata[name] = File.expand_path(path).untaint
    end

    def self.[](name)
      self.find!(name)
    end

    def self.find(name)
      return @testdata[name] if @testdata[name]

      result = repos[(@mock+name.sub('private/','')).to_s.sub(/\/*$/, '')] ||
        repos[(@base+name).to_s.sub(/\/*$/, '')] # lose trailing slash

      return result if result

      # recursively try parent directory
      if name.include? '/'
        base = File.basename(name).untaint
        result = find(File.dirname(name))
        if result and File.exist?(File.join(result, base))
          File.join(result, base)
        end
      end
    end

    def self.find!(name)
      result = self.find(name)

      if not result
        raise Exception.new("Unable to find svn checkout for #{@base + name}")
      end

      result
    end

    # retrieve revision, content for a file in svn
    def self.get(path, user=nil, password=nil)
      # build svn info command
      cmd = ['svn', 'info', path, '--non-interactive']

      # password was supplied, add credentials
      if password
        cmd += ['--username', user, '--password', password, '--no-auth-cache']
      end

      # default the values to return
      revision = '0'
      content = nil

      # issue svn info command
      stdout, status = Open3.capture2(*cmd)
      if status.success?
        # extract revision number
        revision = stdout[/^Revision: (\d+)/, 1]

        # extract contents
        cmd[1] = 'cat'
        content, status = Open3.capture2(*cmd)
      end

      # return results
      return revision, content
    end

    # update a file or directory in SVN, working entirely in a temporary
    # directory
    def self.update(path, msg, env, _, options={})
      if File.directory? path
        dir = path
        basename = nil
      else
        dir = File.dirname(path)
        basename = File.basename(path)
      end

      if path.start_with? '/' and not path.include? '..' and File.exist?(path)
        dir.untaint
        basename.untaint
      end
      
      tmpdir = Dir.mktmpdir.untaint

      begin
        # create an empty checkout
        _.system ['svn', 'checkout', '--depth', 'empty',
          ['--username', env.user, '--password', env.password],
          `svn info #{dir}`[/URL: (.*)/, 1], tmpdir]

        # retrieve the file to be updated (may not exist)
        if basename
          tmpfile = File.join(tmpdir, basename).untaint
          _.system ['svn', 'update',
            ['--username', env.user, '--password', env.password],
            tmpfile]
        else
          tmpfile = nil
        end

        # determine the new contents
        if not tmpfile
          # updating a directory
          previous_contents = contents = nil
          yield tmpdir, ''
        elsif File.file? tmpfile
          # updating an existing file
          previous_contents = File.read(tmpfile)
          contents = yield tmpdir, File.read(tmpfile)
        else
          # updating a new file
          previous_contents = nil
          contents = yield tmpdir, ''
        end
     
        # create/update the temporary copy
        if contents and not contents.empty?
          File.write tmpfile, contents
          if not previous_contents
            _.system ['svn', 'add',
              ['--username', env.user, '--password', env.password],
              tmpfile]
          end
        elsif tmpfile and File.file? tmpfile
          File.unlink tmpfile
          _.system ['svn', 'delete',
            ['--username', env.user, '--password', env.password],
            tmpfile]
        end

        if options[:dryrun]
          # show what would have been committed
          rc = _.system ['svn', 'diff', tmpfile]
        else
          # commit the changes
          rc = _.system ['svn', 'commit', '--message', msg.untaint,
            ['--username', env.user, '--password', env.password],
            tmpfile || tmpdir]
        end

        # fail if there are pending changes
        unless rc == 0 and `svn st`.empty?
          raise "svn failure #{path.inspect}"
        end
      ensure
        FileUtils.rm_rf tmpdir
      end
    end
  end

end
