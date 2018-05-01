# svn update and sort the members.txt file and show the differences

$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
require 'whimsy/asf'

FOUNDATION = ASF::SVN['foundation']

Dir.chdir FOUNDATION

members = FOUNDATION + '/members.txt'
puts 'svn update ' + members
system 'svn update ' + members

source = File.read('members.txt')
sorted = ASF::Member.sort(source)

if source == sorted
  puts 'no change'
else
  File.write('members.txt', sorted)
  system 'svn diff members.txt'
end

