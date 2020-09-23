#!/usr/bin/env ruby

# status methods

require 'socket'
require 'resolv'

# common methods
module Status

  # Are we the active node?
  def self.active?
    Resolv::DNS.open do |rs|
      active = rs.getaddress("whimsy.apache.org") # Official hostname as IP
      current = rs.getaddress(Socket.gethostname) rescue nil # local as IP
      return current == active
    end
  end

  # this hostname
  def self.hostname
    `hostname`.chomp # TODO: could be cached?
  end

  # are we migrating?
  def self.migrating?
    false # Edit as needed
  end

  # are we a test node?
  def self.testnode?
    # Assume test nodes are not called whimsy...[.apache.org]
    hostname !~ %r{^whimsy.*(\.apache\.org)?$}
  end

  # If local updates are not allowed, return reason string, else nil
  # nil if:
  # - active node
  # - not migrating
  # - or testnode
  def self.updates_disallowed_reason
    return nil if testnode?
    return 'Service temporarily unavailable due to migration.' if migrating?
    return 'Service unavailable on this node. Please ensure you have logged in to the correct host.' unless active?

    nil
  end
end

# for debugging purposes
if __FILE__ == $0
  puts "active?: #{Status.active?} hostname: #{Status.hostname} migrating?: #{Status.migrating?}"
  puts "reason: #{Status.updates_disallowed_reason}"
end
