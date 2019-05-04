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
# Monitor status of system
# Currently only checks puppet
#

require 'time'

def Monitor.system(previous_status)
  name=:puppet
  status = {}
  status[name] = {
    command: 'service puppet status',
  }

  begin
    ENV['LC_ALL'] = 'en_US.UTF-8'
    ENV['LANG'] = 'en_US.UTF-8'
    ENV['LANGUAGE'] = 'en_US.UTF-8'

    puppet = `service puppet status`.force_encoding('utf-8').strip

    if puppet.include? 'Active: active (running)'
      status[name].merge! level: 'success', data: puppet.split("\n")
    elsif puppet.include? '* agent is running'
      status[name].merge! level: 'success', data: puppet.split("\n")
    else
      status[name].merge! level: 'warning', data: puppet.split("\n")
    end

  rescue Exception => e
    status[name] = {
      level: 'danger',
      data: {
        exception: {
          level: 'danger',
          text: e.inspect,
          data: e.backtrace
        }
      }
    }
  end

  # Are we the master node?
  begin
    require_relative '../../whimsy'
    master = Whimsy.master?
    rescue LoadError, StandardError => e
      master = e.inspect
  end
  name = :master
  status[name] = {command: 'Whimsy.master?'}
  # TODO change the false level to warning or danger at some point?
  # N.B. need to compare with true as master may be a string, i.e. 'truthy'
  status[name] = {level: master == true ? 'success' : 'warning',
                  data: master.to_s}

# No longer relevant as we use standard alias names
#  # Is ASF::LDAP.hosts up to date?
#  require_relative '../../../lib/whimsy/asf'
#  name = :ldap
#  pls = ASF::LDAP.puppet_ldapservers.sort
#  hosts = ASF::LDAP::RO_HOSTS.sort
#  diff = (pls-hosts).map {|host| "+ #{host}"}
#  diff += (hosts-pls).map {|host| "- #{host}"}
#  if diff.empty?
#    status[name] = {level: 'success', data: hosts}
#  else
#    status[name] = {level: 'warning', data: diff}
#  end

  {data: status}
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('system') # must agree with method name above
end
