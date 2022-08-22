# load configuration information from $HOME/.whimsy

require 'yaml'
require 'etc'

module ASF

  #
  # Support for local (development) configuration overrides to be stored in
  # <tt>.whimsy</tt> files in YAML format.  Allows the specification of where
  # subversion, git, and other files are stored, where updated files are
  # cached, mailing list configuration, and other values.
  #
  # Any .whimsy file in your home directory is processed first.
  #
  # Additionally, a search is made for .whimsy files in the current working
  # directory and then working up the directory path and finally in /srv.
  # If such a .whimsy file is found, it will be processed for
  # overrides to the configuration.
  #
  # The configuration value of :root:, if provided, will establish the default
  # root directory for a number of files/directories (among them, svn, git, and
  # subscriptions).  If the value is '.' and the parent directory for this
  # file contains a `whimsy` subdirectory, then the parent directory will
  # be considered the root.
  #
  class Config
    @home = ENV['HOME'] || Dir.home(Etc.getpwuid.name)

    @config = {}
    home_config = "#{@home}/.whimsy"
    @config.merge!(YAML.load_file(home_config) || {}) if File.exist? home_config

    # Search up the directory path for a .whimsy file containing overrides.
    # Default @root to /srv if no such file is found.
    @root = File.realpath(Dir.pwd)
    @root = loop do
      break '/srv' if @root == @home
      break @root if File.exist? "#{@root}/.whimsy"
      break '/srv' if @root == '/'

      @root = File.dirname(@root)
    end

    root_config = "#{@root}/.whimsy"
    if File.exist? root_config
      @config.merge! YAML.load_file(root_config) || {}
      @root = '/srv' unless Dir.exist? File.join(@root, "whimsy")
    end

    # capture root
    if @config[:root] == '.'
      @config[:root] ||= @root
    elsif @config[:root]
      @root = @config[:root]
    else
      @root = '/srv'
    end

    # allow for test overrides
    @testdata = {}

    # default :svn and :git
    @config[:svn] ||= "#{@root}/svn/*"
    @config[:git] ||= "#{@root}/git/*"

    # The cache is used for local copies of SVN files that may be updated by Whimsy
    # for example: podlings.xml
    # www/roster/views/actions/ppmc.json.rb (write)
    # lib/whimsy/asf/podlings.rb (read)
    # see: http://mail-archives.apache.org/mod_mbox/whimsical-dev/201705.mbox/%3CCAFG6u8FJwvWvnd29O-cUZyQnCXrRvWSRDc11zaPx6_Y4ihnsfg%40mail.gmail.com%3E
    @config[:cache] ||= "#{@root}/cache"

    # Contains the data files from the ezmlm mail server, e.g.
    # cache/ directory tree
    # The above are used by mlist.rb
    # list-flags - flags domain listname
    # The above are used by mail.rb
    @config[:subscriptions] ||= "#{@root}/subscriptions"

    @config[:lib] ||= []

    # add gems to lib
    (@config[:gem] || {}).to_a.reverse.each do |name, version|
      begin
        gem = Gem::Specification.find_by_name(name, version)
        @config[:lib] += Dir[gem.lib_dirs_glob]
      rescue Gem::LoadError
        # ignored
      end
    end

    # add libraries to RUBYLIB, load path
    (@config[:lib] || []).reverse.each do |lib|
      next unless File.exist? lib

      lib = File.realpath(lib)
      ENV['RUBYLIB'] = ([lib] + ENV['RUBYLIB'].to_s.split(':')).uniq.join(':')
      $LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
    end

    # Look up a configuration value by name (generally a symbol, like
    # <tt>:svn</tt>).
    def self.get(value)
      @config[value]
    end

    # Look up a configuration value by name (generally a symbol, like
    # <tt>:svn</tt>). Allows test overrides
    def self.[](value)
      @testdata[value] || @config[value]
    end

    # Set a local directory corresponding to a path
    # Useful as a test data override.
    def self.[]=(name, path)
      @testdata[name] = File.expand_path(path)
    end

    def self.root
      @root
    end

    # For testing only!!
    def self.setroot(path)
      @root = path
    end

    # Testing only: override svn config
    # path must end in /*
    def self.setsvnroot(path)
      raise RuntimeError "Invalid path: #{path}" unless path.end_with? '/*'

      @config[:svn] = path
    end
  end

end

# For debugging purposes, dump the configuration
if __FILE__ == $0
  require 'pp'
  pp ASF::Config.instance_variable_get(:@config)
end
