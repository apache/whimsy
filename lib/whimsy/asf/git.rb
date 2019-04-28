##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

require 'thread'
require 'open3'

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
  
    # get a file live from infrastructure puppet (e.g. 'data/common.yaml')
    # issues a HTTP GET request, so may be slow and may fail.  For applications
    # that require faster and more dependable access,
    # <tt>ASF::Git.find('infrastructure-puppet')</tt> may be used to get
    # access to a clone that is updated every 10 minutes.
    def self.infra_puppet(file)
      file = INFRA_PUPPET + file
      http = Net::HTTP.new(GITHUB_HOST, 443)
      http.use_ssl = true
      http.request(Net::HTTP::Get.new(file)).body
    end

    # path to <tt>repository.yml</tt> in the source.
    REPOSITORY = File.expand_path('../../../../repository.yml', __FILE__).
      untaint

    @semaphore = Mutex.new
    @@repository_mtime = nil

    #
    # Scan a list of git directories, looking for local clones.
    #
    def self.repos
      @semaphore.synchronize do
        git = Array(ASF::Config.get(:git)).map {|dir| dir.untaint}

        unless @repos
          @@repository_mtime = File.exist?(REPOSITORY) && File.mtime(REPOSITORY)

          @repos = Hash[Dir[*git].map { |name|
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

        @repos
      end
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
      result = self.find(name)

      if not result
        raise Exception.new("Unable to find git clone for #{name}")
      end

      result
    end
  end

end
