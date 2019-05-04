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
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous asf_pgpKeyFingerprint: person.attrs['asf-pgpKeyFingerprint']

if @pgpkeys  # must agree with pgpkeys.js.rb

  # report the new values
  _replacement pgpKeyFingerprint: @pgpkeys

  fprints = [] # collect the fingerprints
  @pgpkeys.each do |fp|
    fprint = fp.gsub(' ','').upcase
    if fprint =~ /^[0-9A-F]{40}$/ 
      fprints << fprint        
    else
      _error "'#{fp}' is invalid: expecting 40 hex characters (plus optional spaces)"
      return
    end
  end
  # convert to canonical format
  fprints = fprints.uniq.map do |n| # duplicates not allowed
   "%s %s %s %s %s  %s %s %s %s %s" % n.scan(/..../)
  end
  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'asf-pgpKeyFingerprint', fprints
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
