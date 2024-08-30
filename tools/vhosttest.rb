#!/usr/bin/env ruby

#
# Scaffolding needed to test infrastructure-puppet/modules/vhosts_whimsy/...
# preprocess_vhosts.rb puppet macro
#

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

# Allow override of local repo
IP = ARGV.shift or raise RuntimeError.new 'Need path to infrastructure puppet checkout'
# Allow override of yaml name
base = ARGV.shift || 'whimsy-vm*'
yaml =  Dir["#{IP}/data/nodes/#{base}.apache.org.yaml"].
  max_by {|path| path[/-vm(\d+)/, 1].to_i}

# Create dummy version of function to allow import
module Puppet
  module Functions
    def self.create_function(*_args, &block)
      block.call
    end
  end
end

require 'yaml'
require "#{IP}/modules/vhosts_whimsy/lib/puppet/functions/preprocess_vhosts.rb"

facts = YAML.load_file(yaml)['vhosts_whimsy::vhosts::vhosts']['whimsy-vm-443']
ldap = 'ldap-us.apache.org:636' # No longer defined in whimsy

macros = ApacheVHostMacros.new(facts, ldap)
puts macros.result['custom_fragment'].
  gsub('%%{}', '%').
  sub('%{apache::user}', 'www-data').
  sub('%{apache::group}', 'www-data')
