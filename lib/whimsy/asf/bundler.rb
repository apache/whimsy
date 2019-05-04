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

require 'bundler'
require 'whimsy/asf/config'

module Bundler
  #
  # modify bundler to be aware of whimsy library overrides
  #
  class Dsl
    bundler_gem = instance_method(:gem)
    libs = ASF::Config.get(:lib)

    define_method :gem do |name, *args|
      pname = name.gsub('-', '/')

      path = nil
      libs.each do |lib|
         if File.exist?("#{lib}/#{pname}")
           path = lib
         end
      end

      if path
        args.push({}) unless args.last.is_a?(Hash)
        args.last[:path] = File.dirname(path)
      end

      bundler_gem.bind(self).(name, *args)
    end
  end
end

require 'bundler/setup'
