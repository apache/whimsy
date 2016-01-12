require 'uri'
require 'thread'
require 'open3'

module ASF

  class SVN
    @base = URI.parse('https://svn.apache.org/repos/')
    @mock = 'file:///var/tools/svnrep/'
    @semaphore = Mutex.new
    @testdata = {}

    def self.repos
      @semaphore.synchronize do
        svn = ASF::Config.get(:svn).map {|dir| dir.untaint}
        @repos ||= Hash[Dir[*svn].map { |name| 
          Dir.chdir name.untaint do
            out, err, status = Open3.capture3('svn', 'info')
            if status.success?
              [out[/URL: (.*)/,1].sub(/^http:/,'https:'), Dir.pwd.untaint]
            end
          end
        }.compact]
      end
    end

    def self.[]=(name, path)
      @testdata[name] = File.expand_path(path).untaint
    end

    def self.[](name)
      return @testdata[name] if @testdata[name]

      result = repos[(@mock+name.sub('private/','')).to_s.sub(/\/*$/, '')] ||
        repos[(@base+name).to_s.sub(/\/*$/, '')] # lose trailing slash

      return result if result

      # recursively try parent directory
      if name.include? '/'
        base = File.basename(name)
        result = self[File.dirname(name)]
        if result and File.exist?(File.join(result, base))
          File.join(result, base)
        end
      end
    end
  end

end
