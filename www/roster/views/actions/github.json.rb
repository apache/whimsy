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
# Update GitHub username attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous githubUsername: person.attrs['githubUsername']

if @githubuser

  # report the new values
  _replacement githubUsername: @githubuser

  @githubuser.each do |name|
    # Should agree with the validation in github.js.rb
    unless name =~ /^[-0-9a-zA-Z]+$/ # TODO: might need extending?
      _error "'#{name}' is invalid: must be alphanumeric (or -)"
      return
    end
    # TODO: perhaps check that https://github.com/name exists?    
  end

  unless @dryrun
    names = @githubuser.uniq{|n| n.downcase} # duplicates not allowed; case-blind
    # update LDAP
    _ldap.update do
       person.modify 'githubUsername', names
    end
  end

end

# return updated committer info
_committer Committer.serialize(@userid, env)
