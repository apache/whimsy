#!/usr/bin/env ruby
# Wvisible:tools Crawl scripts and emit homepage related links
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
require 'json'

 # TODO: crawl all tools that might be URLs under www
 # If there's a Wvisible line, store it's cat,egor,ies And long description
startdir = '../www/test'

homelinks = {}

Dir["#{startdir}/*.cgi"].each do |f|
  File.open(f).each_line.map(&:chomp).each do |line|
    if line =~ /^\#\sWvisible\:\s*/i then
      line =~ /# Wvisible:(.*?) (.*)/; line = [$1.split(','), $2]
      puts "2 #{line}"
      homelinks[f] = line # TODO make paths relative for easy _a output
    end
  end
end
puts JSON.pretty_generate homelinks
