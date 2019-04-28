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

# svn update and sort the members.txt file and show the differences

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

FOUNDATION = ASF::SVN['foundation']

Dir.chdir FOUNDATION

members = FOUNDATION + '/members.txt'
puts 'svn update ' + members
system 'svn update ' + members

source = File.read('members.txt')
sorted = ASF::Member.sort(source)

if source == sorted
  puts 'no change'
else
  File.write('members.txt', sorted)
  system 'svn diff members.txt'
end

