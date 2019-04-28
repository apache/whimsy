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

require_relative 'asf/config'
require_relative 'asf/committee'
require_relative 'asf/ldap'
require_relative 'asf/mail'
require_relative 'asf/svn'
require_relative 'asf/git'
require_relative 'asf/watch'
require_relative 'asf/nominees'
require_relative 'asf/icla'
require_relative 'asf/auth'
require_relative 'asf/member'
require_relative 'asf/site'
require_relative 'asf/podling'
require_relative 'asf/person'
require_relative 'asf/themes'

#
# The ASF module contains a set of classes which encapsulate access to a number
# of data sources such as LDAP, ICLAs, auth lists, etc. This code originally
# was developed as a part of separate tools and was later refactored out into a
# common library. Some of the older tools don't fully make use of this
# refactoring.
#

module ASF
  # Last modified time of any file in the entire source tree.
  def self.library_mtime
    parent_dir = File.dirname(File.expand_path(__FILE__))
    sources = Dir.glob("#{parent_dir}/**/*")
    times = sources.map {|source| File.mtime(source.untaint)}
    times.max.gmtime
  end

  # Last commit in this clone, and the date and time of that commit.
  def self.library_gitinfo
    return @info if @info
    @info = `git show --format="%h  %ci"  -s HEAD`.strip
  end
end
