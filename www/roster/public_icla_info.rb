require 'bundler/setup'

require 'whimsy/asf'

GEMVERSION = Gem.loaded_specs['whimsy-asf'].version.to_s rescue nil
  # rescue is to allow for running with local library rather than a Gem

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  output = STDOUT
else
  # exit quickly if there has been no change
  if File.exist? ARGV.first
    source = "#{ASF::SVN['private/foundation/officers']}/iclas.txt"
    lib = File.expand_path('../../../lib', __FILE__)
    mtime = Dir["#{lib}/**/*"].map {|file| File.mtime(file)}.max
    mtime = [mtime, File.mtime(source), File.mtime(__FILE__)].max
    if File.mtime(ARGV.first) >= mtime
      previous_results = JSON.parse(File.read ARGV.first) rescue {}
      exit 0 if previous_results['gem_version'] == GEMVERSION
    end
  end

  output = File.open(ARGV.first, 'w')
end

# gather icla info
ids = {}
noid = []

ASF::ICLA.each do |entry|
  if entry.id == 'notinavail'
    noid << entry.name
  else
    ids[entry.id] = entry.name
  end
end

info = {
  last_updated: ASF::ICLA.svn_change,
  gem_version: GEMVERSION,
  committers: ids,
  non_committers: noid
}

# output results
output.puts JSON.pretty_generate(info)
output.close
