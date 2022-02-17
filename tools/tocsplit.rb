#!/usr/bin/env ruby

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# tocsplit.rb processes agenda/minute file and extracts the Incubator ToCs
# as some were created with more than one copy

require 'digest'

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
    puts "Found #{subs.length-1} ToC sections" # initial section is before ToC
    # Now output the Incubator parts
    p=0
    subs.each do |i|
      p=p+1
      nextf # one file per part
      $out.print i
      if p > 1 && subs.length > 2 # already printed leading section
        h = Digest::SHA256.hexdigest(i)[0..15]
        j = Digest::SHA256.hexdigest(i.gsub(/\s+/,''))[0..15]
        puts "ToC length: #{i.length} hash: #{h} squashed: #{j}"
      end
    end
    nextf # start rest of output
    next # we have already output Incubator
  end
  $out.print s # Output non-Incubator section
end

$out.close if $out
