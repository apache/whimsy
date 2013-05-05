require 'uri'

module ASF

  class SVN
    @base = URI.parse('https://svn.apache.org/repos/')

    def self.repos
      @repos ||= Hash[Dir['/home/whimsysvn/svn/*'].map { |name| 
        Dir.chdir name.untaint do
          [`svn info`[/URL: (.*)/,1].sub(/^http:/,'https:'), Dir.pwd.untaint]
        end
      }]
    end

    def self.[](name)
      repos[(@base+name).to_s.sub(/\/*$/, '')] # lose trailing slash
    end
  end

end
