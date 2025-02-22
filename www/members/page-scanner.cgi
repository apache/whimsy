#!/usr/bin/env ruby
PAGETITLE = "ASF Page Asset Checker - ALPHA" # Wvisible:sites

# very rudimentary page asset checker - shows references to non-ASF assets

require 'open3'
require_relative '../../tools/asf-site-check'

# usage: whimsy.apache.org/members/page-scanner?url=http://apache.org/

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

DIVIDER=' <= '

qs = ENV['QUERY_STRING']
url = option = nil
if qs =~ %r{^url=(https?://[^&]+)(?:&(.+))?}
  url = $1
  option = $2
elsif qs =~ %r{^host=([a-z0-9-]+)(?:&(.+))?$}
  url = "https://#{$1}.apache.org/"
  option = $2
end
if url
  # we only want full URLs
  option = 'allref' unless %w{all showurl}.include? option
  puts <<~EOD

    ** ALPHA CODE **

    Checking the page: #{url} 
    Using option: #{option}


    The following references were found to hosts other than apache.org, openoffice.org and apachecon.com
    The first column shows if the host is recognised as being under ASF control according to
    https://privacy.apache.org/policies/asf-domains

    Note: the script does not yet take account of sites with whom we have a DPA (Data Processing Agreement),
    so it may show some legitimate references

    ======

  EOD
  cmd = ['node', '/srv/whimsy/tools/scan-page.js', url, option]
  out, err, status = Open3.capture3(*cmd)
  if status.success?
    if out == ''
      puts "No external references found"
    else
      puts "Top-level references:"
    end
    extras = Hash.new {|h,k| h[k] = Hash.new}
    out.split(%r{\n+}).each do |url|
      if url.start_with?('ERROR') or url.start_with?('WARN') # console error message (e.g. CSP)
        puts url
      else
        p1, p2 = url.split(DIVIDER)
        if p2
          extras[p2][p1]=1
        else
          print ASFDOMAIN.asfurl?(url) ? 'OK ' : 'NO '
          puts url
        end
      end
    end
    if extras.size > 0
      puts ""
      puts "Transitive references:"
      extras.each do |k, v|
        puts "" #separator
        puts "Loaded by: "+k
        v.each do |url,_|
          print ASFDOMAIN.asfurl?(url) ? 'OK ' : 'NO '
          puts url
          end
      end
    end
  else
    puts err.scan(/^Error:.+/).first || err # Show only the Error line if present
  end
  print "=====\n"
else
  print "Expecting: ?url=http://.../[&showurl] (or ?host=abcd => ?url=https://abcd.apache.org/\n"
end

