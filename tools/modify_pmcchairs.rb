#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'

#
# add/remove people from PMC Chairs
#

require 'whimsy/asf'

# extract action to be performed
dryrun = ARGV.delete('--dryrun')
puts 'Dry run:' if dryrun
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

# get the list of current chairs from committee-info
current = ASF::Committee.pmcs.map(&:chair).uniq

# partition people based on already in pmc-chairs
already_in_pmc_chairs, not_in_pmc_chairs = people.partition{|p| chairs.members.include?(p)}

#puts 'already in pmc-chairs: ' + already_in_pmc_chairs.map{|p|p.name}.join(' ')
#puts 'not in pmc-chairs: ' + not_in_pmc_chairs.map{|p|p.name}.join(' ')

if (action=='--add') & (!already_in_pmc_chairs.empty?)
  puts 'The following ids were not added because they are '\
  'already in ldap group pmc-chairs: ' +
  already_in_pmc_chairs.map{|p| p.name}.join(' ')
end

# only add people to LDAP who are currently chairs in committee-info
not_yet_in_pmc_chairs, not_a_chair = not_in_pmc_chairs.partition{|p| current.include?(p)}
if (action=='--add') & (!not_a_chair.empty?)
  puts 'The following ids were not added because they are '\
  'not listed as a chair in committee-info.txt: ' +
  not_a_chair.map{|p| p.name}.join(' ')
end

# only remove people who are currently in LDAP pmc-chairs
if (action=='--rm') & (!not_in_pmc_chairs.empty?)
  puts 'The following ids were not removed because they are '\
    'not in ldap group pmc-chairs: ' +
    not_in_pmc_chairs.map{|p| p.name}.join(' ')
end

# only remove people from LDAP who are not currently chairs in committee-info
still_chairs, not_chairs = already_in_pmc_chairs.partition{|p| current.include?(p)}
if (action=='--rm') & (!still_chairs.empty?)
  puts 'The following ids were not removed because they are '\
    'still listed as chair in committee-info.txt: ' +
    still_chairs.map{|p| p.name}.join(' ')
end

# identify candidates for removal from LDAP pmc-chairs
candidates_for_removal = chairs.members.select{|p|!current.include?(p)}
puts 'The following members of LDAP pmc-chairs are not currently ' +
  'listed as chairs in committee-info.txt: ' +
  candidates_for_removal.map{|p|p.name}.join(' ')

# identify candidates for addition to LDAP pmc-chairs
candidates_for_addition = current.select{|p|!chairs.members.include?(p)}
puts 'The following chairs in committee-info.txt are not currently ' +
  'listed as members of LDAP pmc-chairs: ' +
candidates_for_addition.map{|p|p.name}.join(' ')

if ((action=='--add') & not_yet_in_pmc_chairs.empty?) |
    ((action=='--rm') & not_chairs.empty?)
  puts 'Nothing to do.'
  exit
end

# execute the action
if action == '--add' and not not_yet_in_pmc_chairs.empty?
  puts 'Adding: ' + not_yet_in_pmc_chairs.map{|p|p.name}.join(' ')
  exit if dryrun
  ASF::LDAP.bind { chairs.add(not_yet_in_pmc_chairs) }
elsif action == '--rm' and not not_chairs.empty?
  puts 'Removing: ' + not_chairs.map{|p|p.name}.join(' ')
  exit if dryrun
  ASF::LDAP.bind { chairs.remove(not_chairs) }
else
  STDERR.puts "Usage: #{$PROGRAM_NAME} [--dryrun] (--add|--rm) list..."
end
