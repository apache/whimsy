#!/usr/bin/env ruby

# utility methods **DRAFT**

require 'socket'
require 'resolv'

# common methods
module Whimsy

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
    `hostname` # TODO: could be cached?
  end

end

# for debugging purposes
if __FILE__ == $0
  puts Whimsy.active?
  puts Whimsy.hostname
end