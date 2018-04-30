require 'uri'
require 'thread'
require 'open3'
require 'fileutils'
require 'tmpdir'

module ASF

  #
  # Provide access to files stored in Subversion, generally to local working
  # copies that are updated via cronjobs.
  #
  # Note: svn paths passed to various #find methods are resolved relative to
  # <tt>https://svn.apache.org/repos/</tt> if they are not full URIs.
  #

  class SVN
    @base = URI.parse('https://svn.apache.org/repos/')
    @mock = 'file:///var/tools/svnrep/'
    @semaphore = Mutex.new
    @testdata = {}

    # path to <tt>repository.yml</tt> in the source.
    REPOSITORY = File.expand_path('../../../../repository.yml', __FILE__).
      untaint
    @@repository_mtime = nil

    # a hash of local working copies of Subversion repositories.  Keys are
    # subversion paths; values are file paths.
    def self.repos
      @semaphore.synchronize do
        svn = Array(ASF::Config.get(:svn)).map {|dir| dir.untaint}

        # reload if repository changes
        if File.exist?(REPOSITORY) && @@repository_mtime!=File.mtime(REPOSITORY)
          @repos = nil
        end

        # reuse previous results if already scanned
        unless @repos
          @@repository_mtime = File.exist?(REPOSITORY) && File.mtime(REPOSITORY)

          @repos = Hash[Dir[*svn].map { |name| 
            next unless Dir.exist? name.untaint
            Dir.chdir name.untaint do
              out, err, status = Open3.capture3('svn', 'info')
              if status.success?
                [out[/URL: (.*)/,1].sub(/^http:/,'https:'), Dir.pwd.untaint]
              end
            end
          }.compact]
        end

        @repos
      end
    end

    # set a local directory corresponding to a path in Subversion.  Useful
    # as a test data override.
    def self.[]=(name, path)
      @testdata[name] = File.expand_path(path).untaint
    end

    # find a local directory corresponding to a path in Subversion.  Throws
    # an exception if not found.
    def self.[](name)
      self.find!(name)
    end

    # find a local directory corresponding to a path in Subversion.  Returns
    # <tt>nil</tt> if not found.
    def self.find(name)
      return @testdata[name] if @testdata[name]

      result = repos[(@mock+name.sub('private/','')).to_s.sub(/\/*$/, '')] ||
        repos[(@base+name).to_s.sub(/\/*$/, '')] # lose trailing slash

      # if name is a simple identifier (may contain '-'), try to match name in repository.yml
      if not result and name =~ /^[\w-]+$/
        entry = YAML.load_file(REPOSITORY)[:svn][name]
        result = find((@base+entry['url']).to_s) if entry
      end

      # recursively try parent directory
      if not result and name.include? '/'
        base = File.basename(name).untaint
        result = find(File.dirname(name))
        if result and File.exist?(File.join(result, base))
          File.join(result, base)
        end
      end

      result
    end

    # find a local directory corresponding to a path in Subversion.  Throws
    # an exception if not found.
    def self.find!(name)
      result = self.find(name)

      if not result
        raise Exception.new("Unable to find svn checkout for #{@base + name}")
      end

      result
    end


    # retrieve info, [err] for a path in svn
    def self.getInfo(path, user=nil, password=nil)
      return nil, 'path must not be nil' unless path

      path = (@base + path).to_s

      # build svn info command
      cmd = ['svn', 'info', path, '--non-interactive']
    
      # password was supplied, add credentials
      if password
        cmd += ['--username', user, '--password', password, '--no-auth-cache']
      end
    
      # issue svn info command
      out, err, status = Open3.capture3(*cmd)
      if status.success?
        return out
      else
        return nil, err
      end
    end

    # retrieve revision, [err] for a path in svn
    def self.getRevision(path, user=nil, password=nil)
      path = (@base + path).to_s

      out, err = getInfo(path, user, password)
      if out
        # extract revision number
        return out[/^Revision: (\d+)/, 1]
      else
        return out, err
      end
    end

    # retrieve revision, content for a file in svn
    def self.get(path, user=nil, password=nil)
      path = (@base + path).to_s

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

    # Updates a working copy, and returns revision number
    #
    # Note: working copies updated out via cron jobs can only be accessed 
    # read only by processes that run under the Apache web server.
    def self.updateSimple(path)
      cmd = ['svn', 'update', path, '--non-interactive']
      stdout, status = Open3.capture2(*cmd)
      revision = 0
      if status.success?
        # extract revision number
        revision = stdout[/^At revision (\d+)/, 1]
      end
      revision
    end

    # update a file or directory in SVN, working entirely in a temporary
    # directory
    # Intended for use from GUI code
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

      # N.B. the extra enclosing [] tell _.system not to show their contents on error
      begin
        # create an empty checkout
        _.system ['svn', 'checkout', '--depth', 'empty', '--non-interactive',
          ['--username', env.user, '--password', env.password],
          `svn info #{dir}`[/URL: (.*)/, 1], tmpdir]

        # retrieve the file to be updated (may not exist)
        if basename
          tmpfile = File.join(tmpdir, basename).untaint
          _.system ['svn', 'update', '--non-interactive',
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
          previous_contents = File.read(tmpfile) if File.file? tmpfile
        end
     
        # create/update the temporary copy
        if contents and not contents.empty?
          File.write tmpfile, contents
          if not previous_contents
            _.system ['svn', 'add', '--non-interactive',
              ['--username', env.user, '--password', env.password],
              tmpfile]
          end
        elsif tmpfile and File.file? tmpfile
          File.unlink tmpfile
          _.system ['svn', 'delete', '--non-interactive',
            ['--username', env.user, '--password', env.password],
            tmpfile]
        end

        if options[:dryrun]
          # show what would have been committed
          rc = _.system ['svn', 'diff', tmpfile]
        else
          # commit the changes
          rc = _.system ['svn', 'commit', tmpfile || tmpdir, '--non-interactive',
            ['--username', env.user, '--password', env.password],
            '--message', msg.untaint]
        end

        # fail if there are pending changes
        unless rc == 0 and `svn st #{tmpfile || tmpdir}`.empty?
          raise "svn failure #{path.inspect}"
        end
      ensure
        FileUtils.rm_rf tmpdir
      end
    end
  end

end

if __FILE__ == $0 # local testing
  path = ARGV.shift||'.'
  puts ASF::SVN.getInfo(path, *ARGV)
  puts ASF::SVN.getRevision(path, *ARGV)
end
