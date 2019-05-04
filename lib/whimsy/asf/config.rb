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

# load configuration information from $HOME/.whimsy

require 'yaml'
require 'etc'

module ASF

  #
  # Support for local (development) configuration overrides to be stored in
  # <tt>~/.whimsy</tt> files in YAML format.  Allows the specification of where
  # subversion, git, and other files are stored, where updated files are
  # cached, mailing list configuration, and other values.
  #
  class Config
    @home = ENV['HOME'] || Dir.home(Etc.getpwuid.name)

    @config = YAML.load_file("#@home/.whimsy") rescue {}

    # default :svn and :git
    @config[:svn] ||= '/srv/svn/*'
    @config[:git] ||= '/srv/git/*'

    # The cache is used for local copies of SVN files that may be updated by Whimsy
    # for example: podlings.xml
    # www/roster/views/actions/ppmc.json.rb (write)
    # lib/whimsy/asf/podlings.rb (read)
    # see: http://mail-archives.apache.org/mod_mbox/whimsical-dev/201705.mbox/%3CCAFG6u8FJwvWvnd29O-cUZyQnCXrRvWSRDc11zaPx6_Y4ihnsfg%40mail.gmail.com%3E
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

    # Look up a configuration value by name (generally a symbol, like
    # <tt>:svn</tt>).
    def self.get(value)
      @config[value]
    end
  end

end
