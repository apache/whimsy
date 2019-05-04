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
_previous mail: person.attrs['mail']

if @email_forward  # must agree with email_forward.js.rb

  # report the new values
  _replacement mail: @email_forward

  @email_forward.each do |mail|
    unless mail.match(URI::MailTo::EMAIL_REGEXP)
      _error "Invalid email address '#{mail}'"
      return
    end
    if mail.downcase.end_with? 'apache.org'
      _error "Invalid email address '#{mail}' (must not be apache.org)"
      return
    end
  end

  if  @email_forward.empty?
    _error "Forwarding email address must not be empty!"
  end

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'mail', @email_forward
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
