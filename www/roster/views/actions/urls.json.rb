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
_previous asf_personalURL: person.attrs['asf-personalURL']

if @urls  # must agree with urls.js.rb

  # report the new values
  _replacement asf_personalURL: @urls

  @urls.each do |url|
#    next
    begin
      uri = URI.parse(url)
    rescue
      _error "Cannot parse URL: #{url}"
      return
    end
    unless uri.scheme =~ /^https?$/ && uri.host.length > 5
      _error "Invalid http(s) URL: #{url}"
      return
    end
  end

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'asf-personalURL', @urls
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
