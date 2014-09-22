# load configuration information from $HOME/.whimsy

require 'yaml'

module ASF

  class Config
    @home = ENV['HOME'] || Dir.pwd

    @config = YAML.load_file("#@home/.whimsy") rescue {}

    # default :svn for backwards compatibility
    @config[:svn] ||= ['/home/whimsysvn/svn/*']

    # add libraries to RUBYLIB, load path
    (@config[:lib] || []).each do |lib|
      next unless File.exist? lib
      ENV['RUBYLIB']=(ENV['RUBYLIB'].to_s.split(':')+[lib]).uniq.join(':')
      $LOAD_PATH << lib unless $LOAD_PATH.include? lib
    end

    def self.get(value)
      @config[value]
    end
  end

end
