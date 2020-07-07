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
    @svnHasPasswordFromStdin = nil

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
          repo_override = ASF::Config.get(:repository)
          if repo_override
            svn_over = repo_override[:svn]
            if svn_over
              require 'wunderbar'
              Wunderbar.warn("Found override for repository.yml[:svn]")
              @@repository_entries[:svn].merge!(svn_over)
            end
          end

          @repos = Hash[Dir[*svn].map { |name| 
            if Dir.exist? name.untaint
              out, _ = self.getInfoItem(name, 'url')
              if out
                [out.sub(/^http:/,'https:'), name]
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
    # @params includeDeleted if should return depth == delete, default false
    def self.repo_entries(includeDelete=false)
      self._all_repo_entries.reject{|k,v| v['depth'] == 'skip' or (v['depth'] == 'delete' and not includeDelete)}
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

    # Construct a repository URL by name and relative path - abort if name is not found
    # Includes aliases
    # assumes that the relative paths are cumulative, unlike URI.merge
    # name - the nickname for the URL
    # relpath - the relative path(s) to the file
    def self.svnpath!(name,*relpath)
      base = self.svnurl!(name)
      base = base + '/' unless base.end_with? '/'
      endpart = [relpath].join('/').sub(%r{^/+},'').gsub(%r{/+},'/')
      return base + endpart
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
      return self.svn('info', path, {user: user, password: password})
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
      out, err = self.svn('info', path, {item: item,
        user: user, password: password})
      if out
        if item.end_with? 'revision' # svn version 1.9.3 appends trailing spaces to *revision items
          return out.chomp.rstrip
        else
          return out.chomp
        end
      else
        return nil, err
      end
    end

    # retrieve list, [err] for a path in svn
    def self.list(path, user=nil, password=nil)
      return self.svn('list', path, {user: user, password: password})
    end

    # These keys are common to svn_ and svn
    VALID_KEYS=[:user, :password, :verbose, :env, :dryrun, :msg, :depth, :quiet, :item, :revision]

    # common routine to build SVN command line
    # returns [cmd, stdin] where stdin is the data for stdin (if any)
    def self._svn_build_cmd(command, path, options)
      bad_keys = options.keys - VALID_KEYS
      if bad_keys.size > 0
        raise ArgumentError.new "Following options not recognised: #{bad_keys.inspect}"
      end

      # build svn command
      cmd = ['svn', command, '--non-interactive']
      stdin = nil # for use with -password-from-stdin

      msg = options[:msg]
      cmd += ['--message', msg] if msg

      depth = options[:depth]
      cmd += ['--depth', depth] if depth

      cmd << '--quiet' if options[:quiet]

      item = options[:item]
      cmd += ['--show-item', item] if item

      revision = options[:revision]
      cmd += ['--revision', revision] if revision

      # add credentials if required
      env = options[:env]
      if env
        password = env.password
        user = env.user
      else
        password = options[:password]
        user = options[:user]
      end
      unless options[:dryrun] # don't add auth for dryrun
        if password or user == 'whimsysvn' # whimsysvn user does not require password
          cmd << ['--username', user, '--no-auth-cache']
        end
        # password was supplied, add credentials
        if password
          if self.passwordStdinOK?()
            stdin = password
            cmd << ['--password-from-stdin']
          else
            cmd << ['--password', password]
          end
        end
      end

      cmd << '--' # ensure paths cannot be mistaken for options

      if path.is_a? Array
        cmd += path
      else
        cmd << path
      end

      return cmd, stdin
    end

    # low level SVN command
    # params:
    # command - info, list etc
    # path - the path(s) to be used - String or Array of Strings
    # options - hash of:
    #  :msg - ['--message', value]
    #  :depth - ['--depth', value]
    #  :env - environment: source for user and password
    #  :user, :password - used if env is not present
    #  :quiet - if true, apply the --quiet option
    #  :item - [--show-item, value]
    #  :revision - [--revision, value]
    #  :verbose - show command on stdout
    #  :dryrun - return command array as [cmd] without executing it (excludes auth)
    #  :chdir - change directory for system call
    # Returns:
    # - stdout
    # - nil, err
    # - [cmd] if :dryrun
    # May raise ArgumentError
    def self.svn(command, path , options = {})
      raise ArgumentError.new 'command must not be nil' unless command
      raise ArgumentError.new 'path must not be nil' unless path
      
      # Deal with svn-only opts
      chdir = options.delete(:chdir)
      open_opts = {}
      open_opts[:chdir] = chdir if chdir

      cmd, stdin = self._svn_build_cmd(command, path, options)

      cmd.flatten!
      open_opts[:stdin_data] = stdin if stdin

      p cmd if options[:verbose]

      return [cmd] if options[:dryrun]

      # issue svn command
      out, err, status = Open3.capture3(*cmd, open_opts)

      # Note: svn status exits with status 0 even if the target directory is missing or not a checkout
      if status.success?
        if out == '' and err != '' and %w(status stat st).include? command
          return nil, err
        else
          return out
        end
      else
        return nil, err
      end
    end

    # low level SVN command for use in Wunderbar context (_json, _text etc)
    # params:
    # command - info, list etc
    # path - the path(s) to be used - String or Array of Strings
    # _ - wunderbar context
    # options - hash of:
    #  :msg - ['--message', value]
    #  :depth - ['--depth', value]
    #  :quiet - if true, apply the --quiet option
    #  :item - [--show-item, value]
    #  :revision - [--revision, value]
    #  :auth - authentication (as [['--username', etc]])
    #  :env - environment: source for user and password
    #  :user, :password - used if env is not present
    #  :verbose - show command (including credentials) before executing it
    #  :dryrun - show command (excluding credentials), without executing it
    #  :sysopts - options for BuilderClass#system, e.g. :stdin, :echo, :hilite
    #           - options for JsonBuilder#system, e.g. :transcript, :prefix
    #
    # Returns:
    # - status code
    # May raise ArgumentError
    def self.svn_(command, path, _, options = {})
      raise ArgumentError.new 'command must not be nil' unless command
      raise ArgumentError.new 'path must not be nil' unless path
      raise ArgumentError.new 'wunderbar (_) must not be nil' unless _
      
      # Pick off the options specific to svn_ rather than svn
      sysopts = options.delete(:sysopts) || {}
      auth = options.delete(:auth)
      if auth
        # override any other auth
        [:env, :user, :password].each do |k|
          options.delete(k)
        end
      end


      cmd, stdin = self._svn_build_cmd(command, path, options)
      sysopts[:stdin] = stdin if stdin
      if auth # insert after the command name
        cmd.insert(2, auth, '--no-auth-cache')
      end

      # This ensures the output is captured in the response
      _.system ['echo', [cmd,sysopts].inspect] if options[:verbose] # includes auth

      if options[:dryrun] # excludes auth
        return _.system cmd.insert(0,'echo')
      end

      #  N.B. Version 1.3.3 requires separate hashes for JsonBuilder and BuilderClass,
      #  see https://github.com/rubys/wunderbar/issues/11
      if _.instance_of?(Wunderbar::JsonBuilder) or _.instance_of?(Wunderbar::TextBuilder)
        _.system cmd, sysopts, sysopts # needs two hashes
      else
        _.system cmd, sysopts
      end
    end

    # As for self.svn_, but failures cause a RuntimeError
    def self.svn_!(command, path, _, options = {})
      rc = self.svn_(command, path, _, options = options)
      raise RuntimeError.new("exit code: #{rc}") if rc != 0
      rc
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
    # N.B. There is a window between fetching the revision and getting the file contents
    def self.get(path, user=nil, password=nil)
      revision, _ = self.getInfoItem(path, 'revision', {user: user, password: password})
      if revision
        content, _ = self.svn('cat', path, {user: user, password: password})
      else
        revision = '0'
        content = nil
      end
      return revision, content
    end

    # Updates a working copy, and returns revision number
    #
    # Note: working copies updated out via cron jobs can only be accessed 
    # read only by processes that run under the Apache web server.
    def self.updateSimple(path)
      stdout, _ = self.svn('update',path)
      revision = 0
      if stdout
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
      ciURL = options[:url] || self.svnurl('board').untaint
      Dir.mktmpdir do |tmpdir|
        # use dup to make testing easier
        user = env.user.dup.untaint
        pass = env.password.dup.untaint
        # checkout committers/board (this does not have many files currently)
        out, err = self.svn('checkout', [ciURL, tmpdir.untaint],
          {quiet: true, depth: 'files',
           user: user, password: pass})

        raise Exception.new("Checkout of board folder failed: #{err}") unless out

        # read in committee-info.txt
        file = File.join(tmpdir, 'committee-info.txt')
        info = File.read(file)

        info = yield info # get the updates the contents

        # write updated file to disk
        File.write(file, info)

        # commit the updated file
        out, err = self.svn('commit', [file, tmpdir.untaint],
          {quiet: true, msg: msg,
           user: user, password: pass})

        raise Exception.new("Update of committee-info.txt failed: #{err}") unless out
        
      end
    end

    # update a file or directory in SVN, working entirely in a temporary
    # directory
    # Intended for use from GUI code
    # Must be used with a block, which is passed the temporary directory name
    # and the current file contents (may be empty string)
    # The block must return the updated file contents
    #
    # Parameters:
    # path - the path to be used, directory or single file
    # msg - commit message
    # env - environment (queried for user and password)
    # _ - wunderbar context
    # options - hash of:
    #  :dryrun - show command (excluding credentials), without executing it
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
        self.svn_('checkout', [self.getInfoItem(dir,'url'), tmpdir], _,
          {depth: 'empty', env: env})

        # retrieve the file to be updated (may not exist)
        if basename
          tmpfile = File.join(tmpdir, basename).untaint
          self.svn_('update', tmpfile, _, {env: env})
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
            self.svn_('add', tmpfile, _, {env: env}) # TODO is auth needed here?
          end
        elsif tmpfile and File.file? tmpfile
          File.unlink tmpfile
          self.svn_('delete', tmpfile, _, {env: env}) # TODO is auth needed here?
        end

        if options[:dryrun]
          # show what would have been committed
          rc = self.svn_('diff', tmpfile || tmpdir, _)
          return rc # No point checking for pending changes
        else
          # commit the changes
          rc = self.svn_('commit', tmpfile || tmpdir, _,
             {msg: msg.untaint, env: env})
        end

        # fail if there are pending changes
        out, err = self.svn('status', tmpfile || tmpdir) # Need to use svn rather than svn_ here
        unless rc == 0 && out && out.empty?
          raise "svn failure #{rc} #{path.inspect} #{out}"
        end
      ensure
        FileUtils.rm_rf tmpdir
      end
      rc # return last status
    end

    # DRAFT DRAFT DRAFT
    # Low-level interface to svnmucc, intended for use with wunderbar
    # Parameters:
    #   commands - array of commands
    #   msg - commit message
    #   env - environment (username/password)
    #   _ - Wunderbar context
    #   revision - the --revision svnmucc parameter (unless nil)
    #   options - hash:
    #     :tmpdir - use this temporary directory (and don't remove it)
    #     :verbose - if true, show command details
    #     :dryrun - if true, don't execute command, but show it instead
    #     :root - interpret all action URLs relative to the specified root
    # The commands must themselves be arrays to ensure correct processing of white-space
    # For example:
    #     commands = []
    #     url1 = 'https://svn.../' # etc
    #     commands << ['mv',url1,url2]
    #     commands << ['rm',url3]
    #   ASF::SVN.svnmucc_(commands,message,env,_,revision)
    def self.svnmucc_(commands, msg, env, _, revision, options={})

      raise ArgumentError.new 'commands must be an array' unless Array === commands
      raise ArgumentError.new 'msg must not be nil' unless msg
      raise ArgumentError.new 'env must not be nil' unless env
      raise ArgumentError.new '_ must not be nil' unless _

      bad_keys = options.keys - [:dryrun, :verbose, :tmpdir, :root]
      if bad_keys.size > 0
        raise ArgumentError.new "Following options not recognised: #{bad_keys.inspect}"
      end

      require 'tempfile'
      temp = options[:tmpdir]
      tmpdir = temp ? temp : Dir.mktmpdir.untaint

      begin
        cmdfile = Tempfile.new('svnmucc_input', tmpdir)
        # add the commands
        commands.each do |cmd|
          raise ArgumentError.new 'command entries must be an array' unless Array === cmd
          cmd.each do |arg|
            cmdfile.puts(arg)
          end
          cmdfile.puts('')
        end
        cmdfile.rewind
        cmdfile.close

        syscmd = ['svnmucc',
                  '--non-interactive',
                  '--extra-args', cmdfile.path.untaint,
                  '--message', msg,
                  '--no-auth-cache',
                  ]
        if revision
          syscmd << '--revision'
          syscmd << revision 
        end
        root = options[:root]
        if root
          syscmd << '--root-url'
          syscmd << root 
        end

        sysopts = {}
        if env
          if self.passwordStdinOK?()
            syscmd << ['--username', env.user, '--password-from-stdin']
            sysopts[:stdin] = env.password
          else
            syscmd << ['--username', env.user, '--password', env.password]
          end
        end
        if options[:verbose]
          _.system 'echo',[syscmd.flatten,sysopts.to_s]
        end
        if options[:dryrun]
          _.system syscmd.insert(0,'echo')
        else
          if _.instance_of?(Wunderbar::JsonBuilder) or _.instance_of?(Wunderbar::TextBuilder)
            _.system syscmd, sysopts, sysopts # needs two hashes
          else
            _.system syscmd, sysopts
          end
        end
      ensure
        File.delete cmdfile.path.untaint # always drop the command file
        FileUtils.rm_rf tmpdir unless temp
      end
    end

    # DRAFT DRAFT
    # create a new file and fail if it already exists
    # Parameters:
    #  directory - parent directory as an SVN URL
    #  filename - name of file to create
    #  source - file to upload
    #  msg - commit message
    #  env - user/pass
    #  _ - wunderbar context
    # Returns:
    # 0 on success
    # 1 if the file exists
    # RuntimeError on unexpected error
    def self.create_(directory, filename, source, msg, env, _)
      parentrev, err = self.getInfoItem(directory, 'revision', env.user, env.password)
      unless parentrev
        throw RuntimeError.new("Failed to get revision for #{directory}: #{err}")
      end
      target = File.join(directory, filename)
      out, err = self.svn('list', target, {env: env})
      return 1 if out # already exists
      # Need to check for unexpected errors; the error message does not include the full repo URL
      unless err =~ %r{^svn: warning: W160013: Path '.+#{filename}' not found}
        throw RuntimeError.new("#{filename} already exists! #{err}")
      end
      commands = [['put', source, target]]
      self.svnmucc_(commands, msg, env, _, parentrev)
    end

    # DRAFT DRAFT DRAFT
    # checkout file and update it using svnmucc put
    # the block can return additional info, which is used 
    # to generate extra commands to pass to svnmucc
    # which are included in the same commit
    # The extra parameter is an array of commands
    # These must themselves be arrays to ensure correct processing of white-space
    # Parameters:
    #   path - file path or SVN URL (http(s) or file:)
    #   message - commit message
    #   env - for username and password
    #   _ - Wunderbar context
    # For example:
    #   ASF::SVN.multiUpdate_(path,message,env,_) do |text|
    #     out = '...'
    #     extra = []
    #     url1 = 'https://svn.../' # etc
    #     extra << ['mv',url1,url2]
    #     extra << ['rm',url3]
    #     [out, extra]
    #   end
    def self.multiUpdate_(path, msg, env, _, options = {})
      require 'tempfile'
      tmpdir = Dir.mktmpdir.untaint
      if File.file? path
        basename = File.basename(path).untaint
        parentdir = File.dirname(path).untaint
        parenturl = ASF::SVN.getInfoItem(parentdir,'url')
      else
        uri = URI.parse(path)
        # allow file: URIs for local testing
        isFile = (uri.is_a? URI::File rescue false) # URI::File is not in 2.3.1
        if isFile or uri.is_a? URI::HTTPS # includes HTTPS
          basename = File.basename(uri.path).untaint
          parentdir = File.dirname(uri.path).untaint
          uri.path = parentdir
          parenturl = uri.to_s
        else
          raise ArgumentError.new("Path '#{path}' must be a file or URL")
        end
      end
      outputfile = File.join(tmpdir, basename).untaint
      cmdfile = nil

      begin

        # create an empty checkout
        rc = self.svn_('checkout', [parenturl, tmpdir], _, {depth: 'empty', env: env})
        raise "svn failure #{rc} checkout #{parenturl}" unless rc == 0

        # checkout the file
        rc = self.svn_('update', outputfile, _, {env: env})
        raise "svn failure #{rc} update #{outputfile}" unless rc == 0

        # N.B. the revision is required for the svnmucc put to prevent overriding a previous update
        # this is why the file is checked out rather than just extracted
        filerev = ASF::SVN.getInfoItem(outputfile,'revision',env.user,env.password) # is auth needed here?
        fileurl = ASF::SVN.getInfoItem(outputfile,'url',env.user,env.password)

        # get the new file contents and any extra svn commands
        contents, extra = yield File.read(outputfile)

        # update the file
        File.write outputfile, contents

        # build the svnmucc commands
        cmds = []
        cmds << ['put', outputfile, fileurl]

        extra.each do |cmd|
          cmds << cmd
        end
        
        # Now commit everything
        if options[:dryrun]
          puts cmds # TODO: not sure this is correct for Wunderbar
        else
          rc = ASF::SVN.svnmucc_(cmds,msg,env,_,filerev,{tmpdir: tmpdir})
          raise "svnmucc failure #{rc} committing" unless rc == 0
          rc
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
    # - tag: previous tag to check for changes, default nil
    # - trimSlash: whether to trim trailing '/', default true
    # @return tag, Array of names
    # or tag, nil if unchanged
    # or Exception if error
    # The tag should be regarded as opaque
    def self.getlisting(name, tag=nil, trimSlash = true)
      listfile, _ = self.listingNames(name)
      curtag = "%s:%d" % [trimSlash, File.mtime(listfile)]
      if curtag == tag
        return curtag, nil
      else
        open(listfile) do |l|
          # fetch the file revision from the first line
          _filerev = l.gets.chomp # TODO should we be checking _filerev?
          if trimSlash
            return curtag, l.readlines.map {|x| x.chomp.chomp('/')}
          else
            return curtag, l.readlines.map(&:chomp)
          end
        end
      end
    end

    # Does this host's installation of SVN support --password-from-stdin?
    def self.passwordStdinOK?()
      return @svnHasPasswordFromStdin unless @svnHasPasswordFromStdin.nil?
        out, err, status = Open3.capture3('svn','help','cat', '-v')
        if status.success? && out
          @svnHasPasswordFromStdin = out.include? '--password-from-stdin'
        else
          @svnHasPasswordFromStdin = false
        end
      @svnHasPasswordFromStdin
    end

    private
    
    def self.listingNames(name)
      return File.join(ASF::Config.root,'svn',"%s.txt" % name).untaint,
             File.join(ASF::Config.root,'svn',"%s.tmp" % name).untaint
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
