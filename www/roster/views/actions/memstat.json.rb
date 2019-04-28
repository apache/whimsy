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

# get entry for @userid
entry = ASF::Person.find(@userid).members_txt(true)
raise Exception.new("unable to find member entry for #{userid}") unless entry

# identify file to be updated
members_txt = File.join(ASF::SVN['foundation'], 'members.txt')

# construct commit message
message = "Move #{ASF::Person.find(@userid).member_name} to #{@action}"

# update members.txt
_svn.update members_txt, message: message do |dir, text|
  # remove user's entry
  text.sub! entry, ''

  # determine where to put the entry
  if @action == 'emeritus'
    index = text.index(/^\s\*\)\s/, text.index(/^Emeritus/))
  elsif @action == 'active'
    index = text.index(/^\s\*\)\s/, text.index(/^Active/))
  else
    raise Exception.new("invalid action #{action.inspect}")
  end

  # perform the insertion
  text.insert index, entry

  # save the updated text
  ASF::Member.text = text

  # return the updated (and normalized) text
  ASF::Member.text
end

# return updated committer info
_committer Committer.serialize(@userid, env)
