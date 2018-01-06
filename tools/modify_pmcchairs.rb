#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))

#
# add/remove people from PMC Chairs
#

require 'whimsy/asf'

# extract action to be performed
action = ARGV.delete('--add') || ARGV.delete("--rm")

# map arguments provided to people
people = ARGV.map {|id| ASF::Person[id]}

# validate ids
ARGV.zip(people).map do |id, person|
  unless person
    STDERR.puts "invalid id: #{id}"
    exit 1
  end
end

# get the list from LDAP to be updated
chairs = ASF::Service.find('pmc-chairs')

# execute the action
if action == '--add' and not people.empty?
  ASF::LDAP.bind { chairs.add(people) }
elsif action == '-rm' and not people.empty?
  ASF::LDAP.bind { chairs.remove(people) }
else
  STDERR.puts "Usage: #{$PROGRAM_NAME} (--add|--rm) list..."
end
