#!/usr/bin/env ruby

print "Content-type: text/plain\r\n\r\n"

#print ENV.inspect

ENV.sort.each do |k,v|
  print "#{k} #{v}\n"
end

