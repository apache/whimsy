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
# Update packaging information if the previous info is over a day old
# Install update-notifier-common to keep the update-success-stamp current
#

ruby_block 'upgrade subversion' do
  block do
    if File.exist? '/mnt/svn/foundation/.svn/format'
      cmd = Chef::ShellOut.new(
        'apt-key adv --keyserver keyserver.ubuntu.com --recv-key A2F4C039 2>&1'
      ).run_command

      unless cmd.exitstatus == 0
        Chef::Application.fatal! 'Failed to import subversion signing key'
      end

      File.open('/etc/apt/sources.list.d/subversion.list', 'w') do |file|
        file.write <<-EOF.gsub(/^ +/,'')
          deb http://ppa.launchpad.net/svn/ppa/ubuntu precise main 
          deb-src http://ppa.launchpad.net/svn/ppa/ubuntu precise main
        EOF
      end
    end
  end
end

execute "apt-get-update-periodic" do
  timestamp = '/var/lib/apt/periodic/update-success-stamp'
  command "apt-get update && touch #{timestamp}"
  ignore_failure true
  only_if do
    not File.exists?(timestamp) or File.mtime(timestamp) < Time.now - 86400
  end
end

package 'update-notifier-common'
