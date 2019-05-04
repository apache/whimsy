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

#
# Implement an _svn command for json actions.
#
# Once tested, this code could migrate into whimsy/asf, and be available
# for all Rack application (e.g., secmail, board/agenda, roster)
#

# provide methods to encapsulate LDAP update
module ASF
  class SVN
    class JsonBuilder
      def initialize(env, builder, dryrun)
        @env = env
        @builder = builder
        @dryrun = dryrun
      end

      def update(name, options, &block)
        ASF::SVN.update(name, options[:message], @env, @builder, 
          dryrun: @dryrun, &block)
      end
    end
  end
end

# provide _svn command which forwards requests to the ASF::SVN::JsonBuilder
module Wunderbar
  class JsonBuilder
    def _svn
      ASF::SVN::JsonBuilder.new(env, self, params['dryrun'])
    end
  end
end
