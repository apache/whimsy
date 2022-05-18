require 'uri'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

module ASF

  #
  # Provide access to files stored in Subversion, generally to local working
  # copies that are updated via cronjobs.
  #
  # Note: svn paths passed to various #find methods are resolved relative to
  # <tt>https://svn.apache.org/repos/</tt> if they are not full URIs.
  #

  class SVN
    svn_base = ASF::Config.get(:svn_base)
    if svn_base
      require 'wunderbar'
      Wunderbar.warn("Found override for svn_base: #{svn_base}")
    else
      svn_base = 'https://svn.apache.org/repos/'
    end
    @base = URI.parse(svn_base)
    @mock = 'file:///var/tools/svnrep/'
    @semaphore = Mutex.new
    @testdata = {}

    # path to <tt>repository.yml</tt> in the source.
    REPOSITORY = File.expand_path('../../../../repository.yml', __FILE__)
    @@repository_mtime = nil
    @@repository_entries = nil
    @svnHasPasswordFromStdin = nil

    # a hash of local working copies of Subversion repositories.  Keys are
    # subversion paths; values are file paths.
    def self.repos
      @semaphore.synchronize do
        svn = Array(ASF::Config.get(:svn))

        # reload if repository changes
        if File.exist?(REPOSITORY) && @@repository_mtime != File.mtime(REPOSITORY)
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
            if Dir.exist? name
              out, _ = self.getInfoItem(name, 'url')
              if out
                [out.sub(/^http:/, 'https:'), name]
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
      @testdata[name] = File.expand_path(path)
    end

    # find a local directory corresponding to a path in Subversion.  Throws
    # an exception if not found.
    def self.[](name)
      self.find!(name)
    end

    # Get the SVN repo entries corresponding to local checkouts
    # Excludes depth=delete and depth=skip
    # Optionally return all entries
    # @params
    # includeAll if should return all entries, default false
    def self.repo_entries(includeAll=false)
      if includeAll
        self._all_repo_entries
      else
        self._all_repo_entries.reject {|_k, v| v['depth'] == 'skip' or v['depth'] == 'delete'}
      end
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
      return (@base + url).to_s
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
    def self.svnpath!(name, *relpath)
      base = self.svnurl!(name)
      base += '/' unless base.end_with? '/'
      endpart = [relpath].join('/').sub(%r{^/+}, '').gsub(%r{/+}, '/')
      return base + endpart
    end

    # find a local directory corresponding to a path in Subversion.  Returns
    # <tt>nil</tt> if not found.
    # Excludes aliases
    def self.find(name)
      return @testdata[name] if @testdata[name]

      result = repos[(@mock + name.sub('private/', '')).to_s.sub(/\/*$/, '')] ||
        repos[(@base + name).to_s.sub(/\/*$/, '')] # lose trailing slash

      # if name is a simple identifier (may contain '-'), try to match name in repository.yml
      if not result and name =~ /^[\w-]+$/
        entry = repo_entry(name)
        result = find((@base + entry['url']).to_s) if entry
      end

      # recursively try parent directory
      if not result and name.include? '/'
        base = File.basename(name)
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

      unless result
        entry = repo_entry(name)
        if entry
          raise Exception.new("Unable to find svn checkout for " +
            "#{@base + entry['url']} (#{name})")
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
    def self.list(path, user=nil, password=nil, timestamp=false)
      if timestamp
        return self.svn(['list', '--xml'], path, {user: user, password: password})
      else
        return self.svn('list', path, {user: user, password: password})
      end
    end

    # These keys are common to svn_ and svn
    VALID_KEYS = %i[user password verbose env dryrun msg depth quiet item revision]

    # common routine to build SVN command line
    # returns [cmd, stdin] where stdin is the data for stdin (if any)
    def self._svn_build_cmd(command, path, options)
      bad_keys = options.keys - VALID_KEYS
      if bad_keys.size > 0
        raise ArgumentError.new "Following options not recognised: #{bad_keys.inspect}"
      end

      if command.is_a? String
        # TODO convert to ArgumentError after further testing
        Wunderbar.error "command #{command.inspect} is invalid" unless command =~ %r{^[a-z]+$}
      else
        if command.is_a? Array
          command.each do |cmd|
            raise ArgumentError.new "command #{cmd.inspect} must be a String" unless cmd.is_a? String
          end
          Wunderbar.error "command #{command.first.inspect} is invalid" unless command.first =~ %r{^[a-z]+$}
          command.drop(1).each do |cmd|
            # Allow --option, -lnumber or -x
            Wunderbar.error "Invalid option #{cmd.inspect}" unless cmd =~ %r{^(--[a-z][a-z=]+|-l\d+|-[a-z])$}
          end
        else
          raise ArgumentError.new "command must be a String or an Array of Strings"
        end
      end
      # build svn command
      cmd = ['svn', *command, '--non-interactive']
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
    # Can be array, e.g. ['list', '--xml']
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
    def self.svn(command, path, options = {})
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
    # Can be array, e.g. ['list', '--xml']
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
        %i[env user password].each do |k|
          options.delete(k)
        end
        # convert auth for use by _svn_build_cmd
        auth.flatten.each_slice(2) do |a, b|
          options[:user] = b if a == "--username"
          options[:password] = b if a == "--password"
        end
      end


      cmd, stdin = self._svn_build_cmd(command, path, options)
      sysopts[:stdin] = stdin if stdin

      # This ensures the output is captured in the response
      _.system ['echo', [cmd, sysopts].inspect] if options[:verbose] # includes auth

      if options[:dryrun] # excludes auth
        return _.system cmd.insert(0, 'echo')
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
      raise RuntimeError.new("exit code: #{rc}\n#{_.target!}") if rc != 0
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
      stdout, _ = self.svn('update', path)
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
      ciURL = options[:url] || self.svnurl('board')
      Dir.mktmpdir do |tmpdir|
        # use dup to make testing easier
        user = env.user.dup
        pass = env.password.dup
        # checkout committers/board (this does not have many files currently)
        out, err = self.svn('checkout', [ciURL, tmpdir],
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
        out, err = self.svn('commit', [file, tmpdir],
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
    #  :diff - show diff before committing
    def self.update(path, msg, env, _, options={})
      if File.directory? path
        dir = path
        basename = nil
      else
        dir = File.dirname(path)
        basename = File.basename(path)
      end

      rc = 0
      Dir.mktmpdir do |tmpdir|

        # create an empty checkout
        self.svn_('checkout', [self.getInfoItem(dir, 'url'), tmpdir], _,
          {depth: 'empty', env: env})

        # retrieve the file to be updated (may not exist)
        if basename
          tmpfile = File.join(tmpdir, basename)
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
          unless previous_contents
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
        end

        self.svn_('diff', tmpfile || tmpdir, _) if options[:diff]

        # commit the changes
        rc = self.svn_('commit', tmpfile || tmpdir, _,
            {msg: msg, env: env})

        # fail if there are pending changes
        out, _err = self.svn('status', tmpfile || tmpdir) # Need to use svn rather than svn_ here
        unless rc == 0 && out && out.empty?
          raise "svn failure #{rc} #{path.inspect} #{out}"
        end

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
    #     commands << ['mv', url1, url2]
    #     commands << ['rm', url3]
    #   ASF::SVN.svnmucc_(commands, message, env, _, revision)
    def self.svnmucc_(commands, msg, env, _, revision, options={})

      raise ArgumentError.new 'commands must be an array' unless commands.is_a? Array
      raise ArgumentError.new 'msg must not be nil' unless msg
      raise ArgumentError.new 'env must not be nil' unless env
      raise ArgumentError.new '_ must not be nil' unless _

      bad_keys = options.keys - %i[dryrun verbose tmpdir root]
      if bad_keys.size > 0
        raise ArgumentError.new "Following options not recognised: #{bad_keys.inspect}"
      end

      temp = options[:tmpdir]
      tmpdir = temp ? temp : Dir.mktmpdir

      rc = -1 # in case
      begin
        cmdfile = Tempfile.new('svnmucc_input', tmpdir)
        # add the commands
        commands.each do |cmd|
          raise ArgumentError.new 'command entries must be an array' unless cmd.is_a? Array
          cmd.each do |arg|
            cmdfile.puts(arg)
          end
          cmdfile.puts('')
        end
        cmdfile.rewind
        cmdfile.close

        syscmd = ['svnmucc',
                  '--non-interactive',
                  '--extra-args', cmdfile.path,
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
          _.system 'echo', [syscmd.flatten, sysopts.to_s]
        end
        if options[:dryrun]
          rc = _.system syscmd.insert(0, 'echo')
        else
          if _.instance_of?(Wunderbar::JsonBuilder) or _.instance_of?(Wunderbar::TextBuilder)
            rc = _.system syscmd, sysopts, sysopts # needs two hashes
          else
            rc = _.system syscmd, sysopts
          end
        end
      ensure
        File.delete cmdfile.path # always drop the command file
        FileUtils.rm_rf tmpdir unless temp
      end
      rc
    end

    # DRAFT
    # Check if an svn path exists (at the specified revision)
    # Parameters:
    #  path - the svn uri (http, svn or file)
    #  env - user/pass
    #  options - passed to ASF::SVN.svn('list')
    #
    # Returns:
    # true if the file exists
    # false if the file does not exist
    # IOError on unexpected error
    def self.exist?(path, revision, env, options={})
      out, err = self.svn('list', path, options.merge({env: env, revision: revision}))
      return true if out && (not err)
      # TODO link to where these codes are documented
      if err =~ %r{^svn: warning: W160013: .*(not found|non-existent)}
        return false
      end
      throw IOError.new("Could not check if #{path} exists: #{err}")
    end

    # DRAFT DRAFT
    # create a new file and fail if it already exists
    # Parameters:
    #  directory - parent directory as an SVN URL
    #  filename - name of file to create
    #  text - text of file to create
    #  msg - commit message
    #  env - user/pass
    #  _ - wunderbar context
    # options:
    #   dryrun: passed to svnmucc_
    #
    # Returns:
    # 0 on success
    # 1 if the file exists
    # IOError on unexpected error
    def self.create_(directory, filename, text, msg, env, _, options={})
      parentrev, err = self.getInfoItem(directory, 'revision', env.user, env.password)
      unless parentrev
        throw RuntimeError.new("Failed to get revision for #{directory}: #{err}")
      end
      target = File.join(directory, filename)
      return 1 if self.exist?(target, parentrev, env, options)
      rc = nil
      Dir.mktmpdir do |tmpdir|
        source = Tempfile.new('create_source', tmpdir)
        File.write(source, text)
        commands = [['put', source.path, target]]
        # Detect file created in parallel. This generates the error message:
        # svnmucc: E160020: File already exists: <snip> path 'xxx'
        rc = self.svnmucc_(commands, msg, env, _, parentrev, options.merge({tmpdir: tmpdir}))
        unless rc == 0
          error = _.target?['transcript'][1] rescue ''
          unless error =~ %r{^svnmucc: E160020: File already exists:}
            throw RuntimeError.new("Unexpected error creating file: #{error}")
          end
        end
      end
      rc
    end

    # DRAFT DRAFT DRAFT
    # checkout file and update it using svnmucc put
    # the block can return additional info, which is used
    # to generate extra commands to pass to svnmucc
    # which are included in the same commit
    # The extra parameter is an array of commands
    # These must themselves be arrays to ensure correct processing of white-space
    # Parameters:
    #   path - file path or SVN URL (http(s): or file: or svn:)
    #   message - commit message
    #   env - for username and password
    #   _ - Wunderbar context
    #  options:
    #   :dryrun - don't do the update
    #   :verbose - show what will be done
    #   :tmpdir - use this temporary directory (and don't remove it)
    # For example:
    #   ASF::SVN.multiUpdate_(path, message, env, _) do |text|
    #     out = '...'
    #     extra = []
    #     url1 = 'https://svn.../' # etc
    #     extra << ['mv', url1, url2]
    #     extra << ['rm', url3]
    #     [out, extra]
    #   end
    def self.multiUpdate_(path, msg, env, _, options = {})
      tmpdir = options[:tmpdir] || Dir.mktmpdir
      if File.file? path
        basename = File.basename(path)
        parentdir = File.dirname(path)
        parenturl = ASF::SVN.getInfoItem(parentdir, 'url')
      else
        uri = URI.parse(path)
        # allow file: and svn URIs for local testing
        if %w(http https file svn).include? uri.scheme
          basename = File.basename(uri.path)
          parentdir = File.dirname(uri.path)
          uri.path = parentdir
          parenturl = uri.to_s
        else
          raise ArgumentError.new("Path '#{path}' must be a file or URL")
        end
      end
      outputfile = File.join(tmpdir, basename)

      begin

        # create an empty checkout
        rc = self.svn_('checkout', [parenturl, tmpdir], _, {depth: 'empty', env: env})
        raise "svn failure #{rc} checkout #{parenturl}" unless rc == 0

        # checkout the file
        rc = self.svn_('update', outputfile, _, {env: env})
        raise "svn failure #{rc} update #{outputfile}" unless rc == 0

        # N.B. the revision is required for the svnmucc put to prevent overriding a previous update
        # this is why the file is checked out rather than just extracted
        filerev = ASF::SVN.getInfoItem(outputfile, 'revision', env.user, env.password) # is auth needed here?
        fileurl = ASF::SVN.getInfoItem(outputfile, 'url', env.user, env.password)

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
          rc = ASF::SVN.svnmucc_(cmds, msg, env, _, filerev, {tmpdir: tmpdir, verbose: options[:verbose]})
          raise "svnmucc failure #{rc} committing" unless rc == 0
          rc
        end
      ensure
        FileUtils.rm_rf tmpdir unless options[:tmpdir]
      end
    end

    EPOCH_SEP = ':' # separator
    EPOCH_TAG = 'epoch' + EPOCH_SEP # marker in file to show epochs are present
    EPOCH_LEN = EPOCH_TAG.size
    # update directory listing in /srv/svn/<name>.txt
    # N.B. The listing includes the trailing '/' so directory names can be distinguished
    # @return filerev, svnrev
    # on error return nil, message
    def self.updatelisting(name, user=nil, password=nil, storedates=false, dir = nil)
      url = self.svnurl(name)
      unless url
        return nil, "Cannot find URL for '#{name}'"
      end
      listfile, listfiletmp = self.listingNames(name, dir)
      filerev = "0"
      svnrev = "?"
      filedates = false
      begin
        open(listfile) do |l|
          filerev = l.gets.chomp
          if filerev.start_with? EPOCH_TAG # drop the marker
            filerev = filerev[EPOCH_LEN..-1]
            filedates = true
          end
        end
      rescue
      end
      svnrev, err = self.getInfoItem(url, 'last-changed-revision', user, password)
      if svnrev
        begin
          unless filerev == svnrev && filedates == storedates
            list = self.list(url, user, password, storedates)
            if storedates
              require 'nokogiri'
              require 'date'
              open(listfiletmp, 'w') do |w|
                w.puts "#{EPOCH_TAG}#{svnrev}" # show that this file has epochs
                xml_doc = Nokogiri::XML(list)
                xml_doc.css('entry').each do |entry|
                  kind = entry.css('@kind').text
                  name = entry.at_css('name').text
                  date = entry.at_css('date').text
                  epoch = DateTime.parse(date).strftime('%s')
                  # The separator is the last character of the epoch tag
                  w.puts "%s#{EPOCH_SEP}%s%s" % [epoch, name, kind == 'dir' ? '/' : '']
                end
              end
            else
              open(listfiletmp, 'w') do |w|
                w.puts svnrev
                w.puts list
              end
            end
            File.rename(listfiletmp, listfile)
          end
        rescue Exception => e
          return nil, e.inspect
        end
      else
        return nil, err
      end
      return filerev, svnrev

    end

    # get listing if it has changed
    # @param
    # - name: alias for SVN checkout
    # - tag: previous tag to check for changes, default nil
    # - trimSlash: whether to trim trailing '/', default true
    # - getEpoch: whether to return the epoch if present, default false
    # @return tag, Array of names
    # or tag, nil if unchanged
    # or Exception if error
    # The tag should be regarded as opaque
    def self.getlisting(name, tag=nil, trimSlash = true, getEpoch = false, dir = nil)
      listfile, _ = self.listingNames(name, dir)
      curtag = "%s:%s:%d" % [trimSlash, getEpoch, File.mtime(listfile)]
      if curtag == tag
        return curtag, nil
      else
        open(listfile) do |l|
          # fetch the file revision from the first line
          filerev = l.gets.chomp # TODO should we be checking filerev?
          if filerev.start_with?(EPOCH_TAG)
            if getEpoch
              trimEpoch = -> x { x.split(EPOCH_SEP, 2) } # return as array
            else
              trimEpoch = -> x { x.split(EPOCH_SEP, 2)[1] } # strip the epoch
            end
          else
            trimEpoch = nil
          end
          if trimSlash
            list = l.readlines.map {|x| x.chomp.chomp('/')}
          else
            list = l.readlines.map(&:chomp)
          end
          list = list.map(&trimEpoch) if trimEpoch
          return curtag, list
        end
      end
    end

    # Does this host's installation of SVN support --password-from-stdin?
    def self.passwordStdinOK?
      return @svnHasPasswordFromStdin unless @svnHasPasswordFromStdin.nil?
      out, _err, status = Open3.capture3('svn', 'help', 'cat', '-v')
      if status.success? && out
        @svnHasPasswordFromStdin = out.include? '--password-from-stdin'
      else
        @svnHasPasswordFromStdin = false
      end
      @svnHasPasswordFromStdin
    end

    private

    # Calculate svn parent directory allowing for overrides
    def self.svn_parent
      svn = ASF::Config.get(:svn)
      if svn.instance_of? String and svn.end_with? '/*'
        File.dirname(svn)
      else
        File.join(ASF::Config.root, 'svn')
      end
    end

    # get listing names for updating and returning SVN directory listings
    # Returns:
    # [listing-name, temporary name]
    def self.listingNames(name, dir = nil)
      if dir
        throw IOError.new("Invalid directory #{dir}") unless Dir.exist? dir
      else
        dir = self.svn_parent
      end
      return File.join(dir, "%s.txt" % name),
             File.join(dir, "%s.tmp" % name)
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
