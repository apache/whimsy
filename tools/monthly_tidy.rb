#!/usr/bin/env ruby

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# @(#) monthly tidy-up script

# Script to tidy up directories
#
# Deletes files older than 13 months from the following directories:
# - /srv/mail/board
# - /srv/mail/members
# - /srv/mail/secretary

require 'date'
require 'fileutils'

keep = (Date.today << 13).strftime('%Y%m')

Dir.chdir '/srv/mail'

Dir[*%w(board/20* members/20* secretary/20*)].each do |dir|
  if File.basename(dir) < keep
    begin
      FileUtils.rm_r dir, :verbose => true
    rescue => e
      puts e
    end
  end
end
