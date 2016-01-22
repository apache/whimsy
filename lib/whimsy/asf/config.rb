# load configuration information from $HOME/.whimsy

require 'yaml'

module ASF

  class Config
    @home = ENV['HOME'] || Dir.pwd

    @config = YAML.load_file("#@home/.whimsy") rescue {}

    # default :svn for backwards compatibility
    @config[:svn] ||= ['/srv/svn/*', '/home/whimsysvn/svn/*', "#{@home}/svn/*"]

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
