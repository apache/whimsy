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
# Generate a whimsy.local version of the deployed whimsy configuration
#
# Example usage:
#  ruby vhosttest.rb | ruby mkconf.rb /private/etc/apache2/other/whimsy.conf
#

require 'rbconfig'

if STDIN.tty?
  conf = `ssh whimsy.apache.org cat \
    /etc/apache2/sites-enabled/*-whimsy-vm-443.conf`
else
  conf = STDIN.read
end

conf.sub! 'VirtualHost *:443', 'VirtualHost *:80'
conf.sub! 'ServerName whimsy.apache.org', 'ServerName whimsy.local'

conf.gsub! 'ServerAlias', '## ServerAlias'

conf.gsub! /(\A|\n)\s*RemoteIPHeader.*/, ''

conf.gsub! /\n\s*PassengerDefault.*/, ''
conf.gsub! /\n\s*PassengerUser.*/, ''
conf.gsub! /\n\s*PassengerGroup.*/, ''

conf.gsub! /\n\s*SSL.*/, ''
conf.gsub! /\n\s*## SSL.*/, ''
conf.gsub! "SetEnv HTTPS", "# SetEnv HTTPS"

conf.gsub! '/x1/srv/whimsy', '/srv/whimsy'

conf.sub! /^SetEnv PATH .*/ do |line|
  line[/PATH\s+(\/.*?):/, 1] = '/usr/local/bin'

  line
end

conf.sub! 'wss://', 'ws://'

if ARGV.empty?
  puts conf
else
  ARGV.each do |arg|
    File.write arg, conf
  end
end
