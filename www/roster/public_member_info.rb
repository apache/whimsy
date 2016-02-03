# Public member data
#
# Output looks like:
#
# {
#  "last_updated": "2015-11-29 23:45:50 UTC", // date of members.txt
#  "gem_version": "0.0.75",
#  "code_version": "2016-02-02 17:20:38 UTC",
#  "members": [
#    "m1",
#    "m2",
#    ...
# ],
#  "ex_members": {
#    "e1": "Emeritus (Non-voting) Member",
#    "e2": "Deceased Member",
#    ...
#   }
# }
#
#
#
require 'bundler/setup'

require 'json'
require 'whimsy/asf'

GEMVERSION = Gem.loaded_specs['whimsy-asf'].version.to_s rescue nil
  # rescue is to allow for running with local library rather than a Gem
CODEVERSION = ASF.library_mtime rescue nil

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  output = STDOUT
else
  # exit quickly if there has been no change
  if File.exist? ARGV.first
    source = "#{ASF::SVN['private/foundation']}/members.txt"
    lib = File.expand_path('../../../lib', __FILE__)
    mtime = Dir["#{lib}/**/*"].map {|file| File.mtime(file)}.max
    mtime = [mtime, File.mtime(source), File.mtime(__FILE__)].max
    if File.mtime(ARGV.first) >= mtime
      previous_results = JSON.parse(File.read(ARGV.first)) rescue {}
      exit 0 if previous_results['gem_version'] == GEMVERSION
    end
  end

  output = File.open(ARGV.first, 'w')
end

# gather member info

info = {
    last_updated: (ASF::Member.svn_change rescue nil),
    gem_version: GEMVERSION,
    code_version: CODEVERSION
}

info[:members] = Array.new
info[:ex_members] = Hash.new

ASF::Member.list.each do |e,v|
  s = v['status']
  if s == nil
    info[:members] << e
  else
    info[:ex_members][e] = s
  end
end

# output results (the JSON module does not support sorting, so we pre-sort and rely on insertion order preservation)
info[:members].sort!
info[:ex_members] = Hash[info[:ex_members].sort]

output.puts JSON.pretty_generate(info)
output.close
