#!/usr/bin/env ruby

# status methods

require 'socket'
require 'resolv'

# common methods
module Status
  ACTIVE_HOSTNAME = "whimsy.apache.org"

  # Cache unchanging values
  @currentIP = nil # may not be resolvable
  @hostname = nil

  # Are we the active node?
  # i.e. is our IP address the same as that of the active node
  def self.active?
    Resolv::DNS.open do |rs|
      active = rs.getaddress(ACTIVE_HOSTNAME) # Official hostname as IP; might change during run
      begin
        @currentIP ||= rs.getaddress(hostname) # local as IP; should not change during a run
      rescue Resolv::ResolvError => e # allow this to fail on a test node
        raise unless testnode?
        $stderr.puts "WARNING: Failed to resolve local IP address: #{e}"
      end
      return @currentIP == active
    end
  end

  # this hostname
  def self.hostname
    @hostname ||= Socket.gethostname
    @hostname
  end

  # are we migrating?
  def self.migrating? # This is used to disable updates, see self.updates_disallowed_reason
    File.exist? '/srv/whimsy/migrating.txt' # default is false
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

  def self.currentIP # intended for CLI testing
    Resolv::DNS.open do |rs|
      begin
        @currentIP ||= rs.getaddress(hostname) # local as IP; should not change during a run
      rescue Resolv::ResolvError => e # allow this to fail on a test node
        raise unless testnode?
        $stderr.puts "WARNING: Failed to resolve local IP address: #{e}"
      end
    end
  end

  def self.activeIP # intended for CLI testing
    Resolv::DNS.open.getaddress(ACTIVE_HOSTNAME)
  end

end

# for debugging purposes
if __FILE__ == $0
  puts "hostname: #{Status.hostname}"
  puts "IP: #{Status.currentIP || 'nil'}"
  puts "Active IP: #{Status.activeIP} for #{Status::ACTIVE_HOSTNAME}"
  puts "active?: #{Status.active?}"
  puts "migrating?: #{Status.migrating?}"
  puts "testnode?: #{Status.testnode?}"
  puts "updates disallowed reason: #{Status.updates_disallowed_reason}"
end
