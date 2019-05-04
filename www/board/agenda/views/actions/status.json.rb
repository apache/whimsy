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
# Add action item status updates to pending list
#

Pending.update(env.user, @agenda) do |pending|
  pending['status'] ||= []

  # identify the action to be updated
  update = {
    owner: @owner,
    text: @text,
    pmc: @pmc,
    date: @date
  }

  # search for a match against previously pending status updates
  match = nil
  pending['status'].each do |status|
    found = true
    update.each do |key, value|
      found=false if value != status[key]
    end
    match = status if found
  end

  # if none found, add update to the list
  pending['status'] << update if not match

  # change the status in the update
  update[:status] =
    @status.strip.gsub(/\s+/, ' ').
      gsub(/(.{1,62})(\s+|\Z)/, '\\1' + "\n".ljust(15)).strip

end
