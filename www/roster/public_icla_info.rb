require 'whimsy/asf'

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  output = STDOUT
else
  # exit quickly if there has been no change
  if File.exist? ARGV.first
    source = "#{ASF::SVN['private/committers/board']}/committee-info.txt"
    mtime = [File.mtime(source), File.mtime(__FILE__)].max
    exit 0 if File.mtime(ARGV.first) >= mtime
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
  committers: ids,
  non_committers: noid
}

# output results
output.puts JSON.pretty_generate(info)
output.close
