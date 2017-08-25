#
# Scaffolding needed to test infrastructure-puppet/modules/vhosts_whimsy/...
# preprocess_vhosts.rb puppet macro
#

$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
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

facts = YAML.load_file("#{IP}//data/nodes/whimsy.apache.org.yaml")
facts = facts['vhosts_whimsy::vhosts::vhosts']['whimsy-vm-443']
ldap = ASF::LDAP.hosts.sort.first

macros = Puppet::Parser::Functions::ApacheVHostMacros.new(facts, ldap)
puts macros.result['custom_fragment']
