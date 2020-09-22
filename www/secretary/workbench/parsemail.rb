#!/usr/bin/env ruby

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
