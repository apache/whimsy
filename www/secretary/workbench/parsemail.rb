#!/usr/bin/env ruby
##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.


#
# Parse (and optionally fetch) officer-secretary emails for later
# processing.
#
# Care is taken to recover from improperly formed emails, including:
#   * Malformed message ids
#   * Improper encoding
#   * Invalid from addresses
#

require_relative 'models/mailbox'

Dir.chdir File.dirname(File.expand_path(__FILE__))

if ARGV.include? '--fetch1'
  ARGV.unshift Time.now.strftime('%Y%m')
end

# fetch (selected|all) mailboxes
months = ARGV.select {|arg| arg =~ /^\d{6}$/}
if not months.empty?
  Mailbox.fetch months
elsif ARGV.include? '--fetch1'
  Mailbox.fetch Time.now.strftime('%Y%m')
elsif ARGV.include? '--fetch' or not Dir.exist? ARCHIVE
  Mailbox.fetch
end

# scan each mailbox for updates
width = 0
Dir[File.join(ARCHIVE, '2*')].sort.each do |name|
  # skip YAML files, update output showing latest file being processed
  next if name.end_with? '.yml' or name.end_with? '.mail'
  next if ARGV.any? {|arg| arg =~ /^\d{6}$/} and
    not ARGV.any? {|arg| name.include? "/#{arg}"}
  print "#{name.ljust(width)}\r"
  width = name.length
  
  # parse mailbox
  Mailbox.new(name).parse
end

puts
