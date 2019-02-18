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
