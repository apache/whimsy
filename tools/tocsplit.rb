#!/usr/bin/env ruby

# tocsplit.rb processes agenda/minute file and extracts the Incubator ToCs
# as some were created with more than one copy

file=ARGV.shift or raise "missing file"
TMP=ARGV.shift || '/tmp/tocsplit'

$outn = 100 # so files sort
$out = nil

# open the next file
def nextf
  $outn += 1
  $out.close if $out
  $out = File.open("#{TMP}#{$outn}.tmp", 'w')
end

contents=File.read(file)

# Split file by start of Attachments
# forward lookahead so match is saved with next part
sections=contents.split(/(?=^-----+\r?\nAttachment A)/)

nextf # Initial section
sections.each do |s|
  # Look for Incubator
  if s =~ /Report from the Apache Incubator Project/
    # split this by ToC sections
    subs = s.split(/(?=^-------+\s+Table\s+of\s+C)/) # one is badly mangled
    puts "Found #{subs.length-1} ToC sections"
    # Now output the Incubator parts
    subs.each do |i|
      nextf # one file per part
      $out.print i
    end
    nextf # start rest of output
    next # we have already output Incubator
  end
  $out.print s # Output non-Incubator section
end

$out.close if $out
