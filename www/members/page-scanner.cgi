#!/usr/bin/env ruby
PAGETITLE = "ASF Page Asset Checker - ALPHA"

# very rudimentary page asset checker - shows references to non-ASF assets

require 'open3'

# usage: whimsy.apache.org/members/page-scanner?url=http://apache.org/

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

# puts ENV['REQUEST_URI']
qs = ENV['QUERY_STRING']
if qs =~ %r{^url=(https?://.+)}
  url = $1
  print "Checking the page #{url}\n\n"
  puts "The following 3rd party references were found."
  puts "They have not been checked against the list of allowed references."
  print "=====\n"
  cmd = ['node', '/srv/whimsy/tools/scan-page.js', url, 'all']
  out, err, status = Open3.capture3(*cmd)
  if status.success?
    puts out
  else
    puts err.scan(/^Error:.+/).first || err # Show only the Error line if present
  end
  print "=====\n"
else
  print "Expecting: ?url=http://.../\n"
end

