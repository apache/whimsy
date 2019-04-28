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
# Scaffolding needed to test infrastructure-puppet/modules/vhosts_whimsy/...
# preprocess_vhosts.rb puppet macro
#

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

IP = ASF::Git['infrastructure-puppet']

module Puppet
  module Parser
    module Functions
      def self.newfunction(*args)
      end
    end
  end
end

require 'yaml'
require "#{IP}/modules/vhosts_whimsy/lib/puppet/parser/functions/preprocess_vhosts.rb"

yaml = Dir["#{IP}/data/nodes/whimsy-vm*.apache.org.yaml"].
  sort_by {|path| path[/-vm(\d+)/, 1].to_i}.last
facts = YAML.load_file(yaml)['vhosts_whimsy::vhosts::vhosts']['whimsy-vm-443']
ldap = ASF::LDAP.hosts.sort.first

macros = Puppet::Parser::Functions::ApacheVHostMacros.new(facts, ldap)
puts macros.result['custom_fragment']
