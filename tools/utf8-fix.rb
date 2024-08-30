#!/usr/bin/env ruby

# @(#) fix non-UTF8 source files

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/utf8-utils'

if __FILE__ == $0
  verbose = !ARGV.delete('-v').nil?
  src = ARGV.shift or raise Exception.new 'need input file'
  dst = ARGV.shift || src + '.tmp'
  puts "Input: #{src} output: #{dst} verbose: #{verbose}"
  UTF8Utils::repair(src, dst, verbose)
  if verbose
    puts 'Above are the changed lines. Note that some may appear the same, but the encoding has changed.'
  end
end
