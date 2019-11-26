#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

#        DRAFT
#        DRAFT
#        DRAFT
#        DRAFT
#        DRAFT
#        DRAFT

# Test ICLA PDF parsing

# Invoke as:
# /secretary/icla-parse/yyyymm/hash/icla.pdf

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

pathinfo = ENV['PATH_INFO']
iclaname = File.basename(pathinfo)
puts "Processing #{pathinfo} to parse #{iclaname}"
puts ""

begin
  require_relative 'workbench/models/mailbox'
  require_relative 'iclaparser'
  
  message = Mailbox.find(pathinfo)
  
  path = message.find(iclaname).as_file.path
  
  ICLAParser.parse(path).sort_by{|k,v| k.to_s }.each do |k,v|
    puts "%-20s %s" % [k,v]
  end
  
rescue Exception => e
  p e
end
