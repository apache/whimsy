require 'whimsy/asf'

OFFICERS = ASF::SVN['officers']

unless OFFICERS
  STDERR.puts 'Unable to locate a checked out version of '
  STDERR.puts ASF::SVN.svnurl!('officers')
  STDERR.puts
  STDERR.puts "Please check your #{Dir.home}/.whimsy file"
  exit 1
end

Dir.chdir OFFICERS
source = File.read('iclas.txt')
sorted = ASF::ICLA.sort(source)

if source == sorted
  puts 'no change'
else
  File.write('iclas.txt', sorted)
  system 'svn diff iclas.txt'
end
