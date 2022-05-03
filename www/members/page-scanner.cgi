#!/usr/bin/env ruby
PAGETITLE = "ASF Page Asset Checker - ALPHA"

# very rudimentary page asset checker - shows references to non-ASF assets

# usage: whimsy.apache.org/members/page-scanner?url=http://apache.org/

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

# puts ENV['REQUEST_URI']
qs = ENV['QUERY_STRING']
if qs =~ %r{^url=(https?://.+)}
  url = $1
  print "Checking the page #{url}\n\n"
  print "=====\n"
  system('node', '/srv/whimsy/tools/scan-page.js', url, 'all')
  print "=====\n"
else
  print "Expecting: ?url=http://.../\n"
end

