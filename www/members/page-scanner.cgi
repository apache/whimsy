#!/usr/bin/env ruby
PAGETITLE = "ASF Page Asset Checker - ALPHA"

# very rudimentary page asset checker - shows references to non-ASF assets

require 'open3'
require_relative '../../tools/asf-site-check'

# usage: whimsy.apache.org/members/page-scanner?url=http://apache.org/

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

# puts ENV['REQUEST_URI']
qs = ENV['QUERY_STRING']
if qs =~ %r{^url=(https?://[^&]+)(?:&(.+))?}
  url = $1
  option = $2
  # we only want full URLs
  option = 'all' unless option == 'showurl'
  print "Checking the page #{url}\n\n"
  puts "The following references were found to hosts other than apache.org and apachecon.com"
  puts "The first column shows if the host is recognised as being under ASF control according to"
  puts "https://privacy.apache.org/policies/asf-domains"
  print "=====\n"
  cmd = ['node', '/srv/whimsy/tools/scan-page.js', url, option]
  out, err, status = Open3.capture3(*cmd)
  if status.success?
    out.split("\n").each do |url|
      print ASFDOMAIN.asfurl?(url) ? 'OK ' : 'NO '
      puts url
    end
  else
    puts err.scan(/^Error:.+/).first || err # Show only the Error line if present
  end
  print "=====\n"
else
  print "Expecting: ?url=http://.../[&showurl]\n"
end

