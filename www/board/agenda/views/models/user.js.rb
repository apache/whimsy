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
# Convenience access to user information (currently residing off of the
# Server.pending data structure).
#

class User
  def self.id
    Server.pending.userid || Server.userid
  end

  def self.initials
    Server.pending.initials || Server.initials
  end

  def self.firstname
    Server.pending.firstname || Server.firstname
  end

  def self.username
    Server.pending.username || Server.username
  end

  def self.role
    if Server.role
      Server.role
    elsif Server.pending and Server.pending.role 
      Server.pending.role
    else
      :guest
    end
  end

  def self.role=(role)
    Server.role = role
  end
end
