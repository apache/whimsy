#!/usr/bin/env ruby
PAGETITLE = "Config Info" # Wvisible:tools config
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

puts "root: #{ASF::Config.root}"

cfg = ASF::Config.instance_variable_get(:@config)


cfg.each do |k,v|
  puts "%s: %s" % [k,v]
end