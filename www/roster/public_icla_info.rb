# Extract public data from iclas.txt

require_relative 'public_json_common'

# gather icla info
ids = {}
noid = []

ASF::ICLA.each do |entry|
  if entry.noId?
    noid << entry.name
  else
    ids[entry.id] = entry.name
  end
end

# 2 files specified - split id/noid into separate files
if ARGV.length == 2

  info_id = {
    last_updated: ASF::ICLA.svn_change,
    committers: Hash[ids.sort]
  }
  public_json_output_file(info_id, ARGV.shift)

  info_noid = {
    last_updated: ASF::ICLA.svn_change,
    see_instead: "https://whimsy.apache.org/officers/unlistedclas.cgi",
    non_committers: [] # deprecated
  }
  public_json_output_file(info_noid, ARGV.shift)

else # combined (original) output file

  info = {
    last_updated: ASF::ICLA.svn_change,
    committers: Hash[ids.sort],
    non_committers: noid # do not sort because the input is already sorted by surname
  }

  public_json_output(info) # original full output

end
