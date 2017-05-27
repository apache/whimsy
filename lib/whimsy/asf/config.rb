# load configuration information from $HOME/.whimsy

require 'yaml'

module ASF

  class Config
    @home = ENV['HOME'] || Dir.pwd

    @config = YAML.load_file("#@home/.whimsy") rescue {}

    # default :svn and :git
    @config[:svn] ||= '/srv/svn/*'
    @config[:git] ||= '/srv/git/*'
    @config[:cache] ||= '/srv/cache'

    @config[:lib] ||= []

    # add gems to lib
    (@config[:gem] || {}).to_a.reverse.each do |name, version|
      begin
        gem = Gem::Specification.find_by_name(name, version)
        @config[:lib] += Dir[gem.lib_dirs_glob]
      rescue Gem::LoadError
      end
    end

    # add libraries to RUBYLIB, load path
    (@config[:lib] || []).reverse.each do |lib|
      next unless File.exist? lib
      lib = File.realpath(lib)
      ENV['RUBYLIB']=([lib] + ENV['RUBYLIB'].to_s.split(':')).uniq.join(':')
      $LOAD_PATH.unshift lib.untaint unless $LOAD_PATH.include? lib
    end

    def self.get(value)
      @config[value]
    end
  end

end
