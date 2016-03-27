$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
require 'whimsy/asf'

OFFICERS = ASF::SVN['private/foundation/officers']

Dir.chdir OFFICERS

iclas = OFFICERS + '/iclas.txt'
puts 'svn update ' + iclas
system 'svn update ' + iclas

source = File.read('iclas.txt')
sorted = ASF::ICLA.sort(source)

if source == sorted
  puts 'no change'
else
  File.write('iclas.txt', sorted)
  system 'svn diff iclas.txt'
end
