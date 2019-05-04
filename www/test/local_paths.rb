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

require 'fileutils'
require 'yaml'
require 'mail'

Dir.chdir File.absolute_path('..', __FILE__)

# Create a 'received' repository in work/repositories
FileUtils.rm_rf 'work'
FileUtils.mkdir_p 'work/repositories'

Dir.chdir 'work/repositories' do
  system 'svnadmin create received'
end

svn = File.absolute_path('work/repositories')

# Checkout 'received' repository into work/svn
FileUtils.mkdir_p 'work/svn'

Dir.chdir 'work/svn' do
  `svn checkout file://#{svn}/received`
end

RECEIVED = File.absolute_path('work/svn/received')

# define pending yaml files
PENDING_YML = File.join(RECEIVED, 'pending.yml')
COMPLETED_YML = File.join(RECEIVED, 'completed.yml')

# define where the mail configuration can be found
MAIL = File.absolute_path('secmail.rb')
