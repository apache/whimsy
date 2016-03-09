require 'thread'
require 'open3'

module ASF

  class Git
    @semaphore = Mutex.new

    def self.repos
      @semaphore.synchronize do
        git = Array(ASF::Config.get(:git)).map {|dir| dir.untaint}
        @repos ||= Hash[Dir[*git].map { |name| 
          next unless Dir.exist? name.untaint
          Dir.chdir name.untaint do
            out, err, status = 
              Open3.capture3(*%(git config --get remote.origin.url))
            if status.success?
              [File.basename(out.chomp, '.git'), Dir.pwd.untaint]
            end
          end
        }.compact]
      end
    end

    def self.[]=(name, path)
      @testdata[name] = File.expand_path(path).untaint
    end

    def self.[](name)
      self.find!(name)
    end

    def self.find(name)
      repos[name]
    end

    def self.find!(name)
      result = self.find(name)

      if not result
        raise Exception.new("Unable to find git clone for #{name}")
      end

      result
    end
  end

end
