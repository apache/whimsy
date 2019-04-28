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

require 'whimsy/asf'

OFFICERS = ASF::SVN['officers']

unless OFFICERS
  STDERR.puts 'Unable to locate a checked out version of '
  STDERR.puts 'https://svn.apache.org/repos/private/foundation/officers.'
  STDERR.ptus
  STDERR.puts "Please check your #{Dir.home}/.whimsy file"
  exit 1
end

Dir.chdir OFFICERS
source = File.read('iclas.txt')
sorted = ASF::ICLA.sort(source)

if source == sorted
  puts 'no change'
else
  File.write('iclas.txt', sorted)
  system 'svn diff iclas.txt'
end
