#!/usr/bin/env ruby

# Test for asfpy chunking

require 'json'

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

$stdout.sync = true

data = {
  data: '1234567890' * 2000
}
out = JSON.generate(data)+"\n"

3.times do
  print out
  sleep 5
end
