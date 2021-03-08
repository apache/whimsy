require 'open3'
require 'net/http'

module ASF

  #
  # Provide access to files stored in Git, generally to local clones that
  # are updated via cronjobs.
  #

  class Git
    # host which can be used to get raw content from git repositories hosted
    # at GitHub.
    GITHUB_HOST = 'raw.githubusercontent.com'

    # path to the deployment branch on GitHub.
    INFRA_PUPPET = '/apache/infrastructure-puppet/deployment/'

    # get a file live from github, e.g. '/apache/petri/master/info.yaml'
    # returns body
    def self.github(file, etag = nil)
      http = Net::HTTP.new(GITHUB_HOST, 443)
      http.use_ssl = true
      return http.request(Net::HTTP::Get.new(file)).body
    end

    # get a file live from infrastructure puppet (e.g. 'data/common.yaml')
    # issues a HTTP GET request, so may be slow and may fail.  For applications
    # that require faster and more dependable access,
    # <tt>ASF::Git.find('infrastructure-puppet')</tt> may be used to get
    # access to a clone that is updated every 10 minutes.
    def self.infra_puppet(file)
      self.github(INFRA_PUPPET + file)
    end


    # path to <tt>repository.yml</tt> in the source.
    REPOSITORY = File.expand_path('../../../repository.yml', __dir__)

    @semaphore = Mutex.new
    @@repository_mtime = nil
    @@repository_entries = nil

    #
    # Scan a list of git directories, looking for local clones.
    #
    def self.repos
      @semaphore.synchronize do
        git = Array(ASF::Config.get(:git))

        # reload if repository changes
        if File.exist?(REPOSITORY) && @@repository_mtime != File.mtime(REPOSITORY)
          @repos = nil
        end

        unless @repos
          @@repository_mtime = File.exist?(REPOSITORY) && File.mtime(REPOSITORY)
          @@repository_entries = YAML.load_file(REPOSITORY)
          repo_override = ASF::Config.get(:repository)
          if repo_override
            git_over = repo_override[:git]
            if git_over
              require 'wunderbar'
              Wunderbar.warn("Found override for repository.yml[:git]")
              @@repository_entries[:git].merge!(git_over)
            end
          end

          @repos = Hash[Dir[*git].map { |name|
            if Dir.exist? name
              out, _, status =
                Open3.capture3('git', 'config', '--get', 'remote.origin.url', {chdir: name})
              if status.success?
                [File.basename(out.chomp, '.git'), name]
              end
            end
          }.compact]
        end

        @repos
      end
    end

    # Get all the Git repo entries
    def self.repo_entries
      self.repos # refresh @@repository_entries
      @@repository_entries[:git]
    end

    #
    # Find a local git clone.  Raises an exception if not found.
    #
    def self.[](name)
      self.find!(name)
    end

    #
    # Find a local git clone.  Returns <tt>nil</tt> if not found.
    #
    def self.find(name)
      repos[name]
    end

    #
    # Find a local git clone.  Raises an exception if not found.
    #
    def self.find!(name)
      result = self.find(name) or raise ArgumentError, "Unable to find git clone for #{name}"

      result
    end
  end

end

if $0 == __FILE__
  require 'net/http'
  puts ASF::Git.github('/apache/petri/master/info.yaml')
  puts ASF::Git.infra_puppet('data/common.yaml') 
end