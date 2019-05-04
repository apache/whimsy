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
# When mail comes in indicating that a repository was updated,
# update the local working copy.
#

require 'mail'

File.umask(0002)

STDIN.binmode
mail = Mail.new(STDIN.read)

LOG = '/srv/whimsy/www/logs/svn-update'

if mail.subject =~ %r{^board: r\d+ -( in)? /foundation/board}

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/foundation_board' do
      `svn cleanup`
      `svn update`
    end
  end

elsif mail.subject =~ %r{^committers: r\d+ -( in)? /committers/board}

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/board' do
      `svn cleanup`
      `svn update`
    end
  end

elsif mail.subject =~ %r{^bills: r\d+ -( in)? /financials/Bills}

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/Bills' do
      `svn cleanup`
      `svn update`
    end
  end

end

