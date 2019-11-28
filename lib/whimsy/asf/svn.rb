require 'uri'
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
    @@repository_entries = nil

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
          @@repository_entries = YAML.load_file(REPOSITORY)

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

    # Get the SVN repo entries corresponding to local checkouts
    # Excludes those that are present as aliases only
    def self.repo_entries
      self._all_repo_entries.reject{|k,v| v['depth'] == 'skip'}
    end

    # fetch a repository entry by name
    # Excludes those that are present as aliases only
    def self.repo_entry(name)
      self.repo_entries[name]
    end

    # fetch a repository entry by name - abort if not found
    def self.repo_entry!(name)
      entry = self.repo_entry(name)
      unless entry
        raise Exception.new("Unable to find repository entry for #{name}")
      end
      entry
    end

    # get private and public repo names
    # Excludes aliases
    # @return [['private1', 'privrepo2', ...], ['public1', 'pubrepo2', ...]
    def self.private_public
      prv = []
      pub = []
      self.repo_entries().each do |name, entry|
        if entry['url'].start_with? 'asf/'
          pub << name
        else
          prv << name
        end
      end
      return prv, pub
    end

    # fetch a repository URL by name
    # Includes aliases
    def self.svnurl(name)
      entry = self._all_repo_entries[name] or return nil
      url = entry['url']
      unless url # bad entry
        raise Exception.new("Unable to find url attribute for SVN entry #{name}")
      end
      return (@base+url).to_s
    end

    # fetch a repository URL by name - abort if not found
		# Includes aliases
    def self.svnurl!(name)
      entry = self.svnurl(name)
      unless entry
        raise Exception.new("Unable to find url for #{name}")
      end
      entry
    end

    # find a local directory corresponding to a path in Subversion.  Returns
    # <tt>nil</tt> if not found.
		# Excludes aliases
    def self.find(name)
      return @testdata[name] if @testdata[name]

      result = repos[(@mock+name.sub('private/','')).to_s.sub(/\/*$/, '')] ||
        repos[(@base+name).to_s.sub(/\/*$/, '')] # lose trailing slash

      # if name is a simple identifier (may contain '-'), try to match name in repository.yml
      if not result and name =~ /^[\w-]+$/
        entry = repo_entry(name)
        result = find((@base+entry['url']).to_s) if entry
      end

      # recursively try parent directory
      if not result and name.include? '/'
        base = File.basename(name).untaint
        parent = find(File.dirname(name))
        if parent and File.exist?(File.join(parent, base))
          result = File.join(parent, base)
        end
      end

      result
    end

    # find a local directory corresponding to a path in Subversion.  Throws
    # an exception if not found.
    def self.find!(name)
      result = self.find(name)

      if not result
        entry = repo_entry(name)
        if entry
          raise Exception.new("Unable to find svn checkout for " +
            "#{@base+entry['url']} (#{name})")
        else
          raise Exception.new("Unable to find svn checkout for #{name}")
        end
      end

      result
    end


    # retrieve info, [err] for a path in svn
    # output looks like:
    #    Path: /srv/svn/steve
    #    Working Copy Root Path: /srv/svn/steve
    #    URL: https://svn.apache.org/repos/asf/steve/trunk
    #    Relative URL: ^/steve/trunk
    #    Repository Root: https://svn.apache.org/repos/asf
    #    Repository UUID: 13f79535-47bb-0310-9956-ffa450edef68
    #    Revision: 1870481
    #    Node Kind: directory
    #    Schedule: normal
    #    Depth: empty
    #    Last Changed Author: somebody
    #    Last Changed Rev: 1862550
    #    Last Changed Date: 2019-07-04 13:21:36 +0100 (Thu, 04 Jul 2019)
    #
    def self.getInfo(path, user=nil, password=nil)
      return nil, 'path must not be nil' unless path

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

    # svn info details as a Hash
    # @return hash or [nil, error message]
    # Sample:
    # {
    #   "Path"=>"/srv/svn/steve",
    #   "Working Copy Root Path"=>"/srv/svn/steve",
    #   "URL"=>"https://svn.apache.org/repos/asf/steve/trunk",
    #   "Relative URL"=>"^/steve/trunk",
    #   "Repository Root"=>"https://svn.apache.org/repos/asf",
    #   "Repository UUID"=>"13f79535-47bb-0310-9956-ffa450edef68",
    #   "Revision"=>"1870481",
    #   "Node Kind"=>"directory",
    #   "Schedule"=>"normal",
    #   "Depth"=>"empty",
    #   "Last Changed Author"=>"somebody",
    #   "Last Changed Rev"=>"1862550",
    #   "Last Changed Date"=>"2019-07-04 13:21:36 +0100 (Thu, 04 Jul 2019)"
    # }
    def self.getInfoAsHash(path, user=nil, password=nil)
      out, err = getInfo(path, user, password)
      if out
        Hash[(out.scan(%r{([^:]+): (.+)[\r\n]+}))]
      else
        return out, err
      end
    end

    # retrieve a single info item, [err] for a path in svn
    # requires SVN 1.9+
    # item must be one of the following:
    #     'kind'       node kind of TARGET
    #     'url'        URL of TARGET in the repository
    #     'relative-url'
    #                  repository-relative URL of TARGET
    #     'repos-root-url'
    #                  root URL of repository
    #     'repos-uuid' UUID of repository
    #     'revision'   specified or implied revision
    #     'last-changed-revision'
    #                  last change of TARGET at or before
    #                  'revision'
    #     'last-changed-date'
    #                  date of 'last-changed-revision'
    #     'last-changed-author'
    #                  author of 'last-changed-revision'
    #     'wc-root'    root of TARGET's working copy
    # Note: Path, Schedule and Depth are not currently supported
    #
    def self.getInfoItem(path, item, user=nil, password=nil)
      return nil, 'path must not be nil' unless path
    
      # build svn info command
      cmd = ['svn', 'info', path, '--non-interactive', '--show-item', item]
    
      # password was supplied, add credentials
      if password
        cmd += ['--username', user, '--password', password, '--no-auth-cache']
      end
    
      # issue svn info command
      out, err, status = Open3.capture3(*cmd)
      if status.success?
        return out.chomp
      else
        return nil, err
      end
    end

    # retrieve list, [err] for a path in svn
    def self.list(path, user=nil, password=nil)
      return nil, 'path must not be nil' unless path

      # build svn info command
      cmd = ['svn', 'list', path, '--non-interactive']

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

    # Specialised code for updating CI
    # Updates cache if SVN commit succeeds
    # user and password are required because the default URL is private
    def self.updateCI(msg, env, options={})
      # Allow override for testing
      ciURL = options[:url] || 'https://svn.apache.org/repos/private/committers/board'
      Dir.mktmpdir do |tmpdir|
        # use dup to make testing easier
        user = env.user.dup.untaint
        pass = env.password.dup.untaint
        # checkout committers/board
        Kernel.system 'svn', 'checkout', '--quiet',
          '--no-auth-cache', '--non-interactive',
          '--depth', 'files',
          '--username', user , '--password', pass,
          ciURL, tmpdir.untaint
        # read in committee-info.txt
        file = File.join(tmpdir, 'committee-info.txt')
        info = File.read(file)

        info = yield info # get the updates the contents

        # write updated file to disk
        File.write(file, info)

        # commit changes
        rc = Kernel.system 'svn', 'commit', '--quiet',
          '--no-auth-cache', '--non-interactive',
          '--username', user, '--password', pass,
          file, '--message', msg

        if rc
          # update cache
          ASF::Committee.parse_committee_info(info)
        else
          # die
          raise Exception.new('Update committee-info.txt failed')
        end
      end
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
        status = `svn st #{tmpfile || tmpdir}`
        unless rc == 0 && status.empty?
          raise "svn failure #{rc} #{path.inspect} #{status}"
        end
      ensure
        FileUtils.rm_rf tmpdir
      end
    end

    # update directory listing in /srv/svn/<name>.txt
    # N.B. The listing includes the trailing '/' so directory names can be distinguished
    # @return filerev, svnrev
    # on error return nil,message
    def self.updatelisting(name, user=nil, password=nil)
      url = self.svnurl(name)
      unless url
        return nil,"Cannot find URL"
      end
      listfile, listfiletmp = self.listingNames(name)
      filerev = "0"
      svnrev = "?"
      begin
        open(listfile) do |l|
          filerev = l.gets.chomp
        end
      rescue
      end
      svnrev, err = self.getInfoItem(url,'last-changed-revision',user,password)
      if svnrev
        begin
          unless filerev == svnrev
            list = self.list(url, user, password)
            open(listfiletmp,'w') do |w|
              w.puts svnrev
              w.puts list
            end
            File.rename(listfiletmp,listfile)
          end
        rescue Exception => e
          return nil,e.inspect
        end
      else
        return nil,err
      end
      return filerev,svnrev

    end

    # get listing if it has changed
    # @param
    # - name: alias for SVN checkout
    # - tag: previous tag to check for changes
    # - trimSlash: whether to trim trailing '/', default true
    # @return tag, Array of names
    # or tag, nil if unchanged
    # or Exception if error
    # The tag should be regarded as opaque
    def self.getlisting(name, tag, trimSlash = true)
      listfile, _ = self.listingNames(name)
      curtag = "%s:%d" % [trimSlash, File.mtime(listfile)]
      if curtag == tag
        return curtag, nil
      else
        open(listfile) do |l|
          filerev = l.gets.chomp
          if trimSlash
            return curtag, l.readlines.map {|x| x.chomp.chomp('/')}
          else
            return curtag, l.readlines.map(&:chomp)
          end
        end
      end
    end

    private
    
    def self.listingNames(name)
      return File.join(ASF::Config.root,'svn',"%s.txt" % name),
             File.join(ASF::Config.root,'svn',"%s.tmp" % name)
    end

    # Get all the SVN entries
    # Includes those that are present as aliases only
    # Not intended for external use
    def self._all_repo_entries
      self.repos # refresh @@repository_entries
      @@repository_entries[:svn]
    end

  end

end

if __FILE__ == $0 # local testing
  class ENV_
    def self.user
      ENV['USER']
    end
    def self.password
      'x x'
    end
  end
  $LOAD_PATH.unshift '/srv/whimsy/lib'
#  require 'whimsy/asf'
  ASF::SVN.updateCI("msg",ENV_,{url: 'file:///Users/sebb/REPO'}) do |content|
    ""
  end
#  path = ARGV.shift||'.'
#  puts ASF::SVN.list(path, *ARGV)
#  puts ASF::SVN.getInfo(path, *ARGV)
#  puts ASF::SVN.getRevision(path, *ARGV)
end
