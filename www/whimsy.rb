require 'socket'
require 'resolv'
module Whimsy
  # Are we the master node?
  def self.master?()
    Resolv::DNS.open do |rs|
      master = rs.getaddress("whimsy.apache.org") # Official hostname as IP
      current = rs.getaddress(Socket.gethostname) rescue nil # local as IP
      return current == master
    end
  end
end

# for debugging purposes
if __FILE__ == $0
  puts Whimsy.master?
end