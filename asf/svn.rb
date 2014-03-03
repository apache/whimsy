require 'uri'
require 'thread'

module ASF

  class SVN
    @base = URI.parse('https://svn.apache.org/repos/')
    @mock = 'file:///var/tools/svnrep/'
    @semaphore = Mutex.new

    def self.repos
      @semaphore.synchronize do
        @repos ||= Hash[Dir['/home/whimsysvn/svn/*'].map { |name| 
          Dir.chdir name.untaint do
            [`svn info`[/URL: (.*)/,1].sub(/^http:/,'https:'), Dir.pwd.untaint]
          end
        }]
      end
    end

    def self.[](name)
      repos[(@mock+name.sub('private/','')).to_s.sub(/\/*$/, '')] ||
        repos[(@base+name).to_s.sub(/\/*$/, '')] # lose trailing slash
    end
  end

end
