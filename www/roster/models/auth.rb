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

class Auth
  def self.info(env)
    ASF::Auth.decode(env)
    info = {id: env.user}

    user = ASF::Person.find(env.user)

    if ASF::Service.find('asf-secretary').members.include? user
      info[:secretary] = true
    end

    if ASF::Service.find('apldap').members.include? user
      info[:root] = true
    end

    if user.asf_member?
      info[:member] = true
    end

    if ASF.pmc_chairs.include? user
      info[:pmc_chair] = true
    end

    info
  end
end
