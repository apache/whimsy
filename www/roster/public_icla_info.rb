# Extract public data from iclas.txt

require_relative 'public_json_common'

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
  committers: Hash[ids.sort],
  non_committers: noid # do not sort because the input is already sorted by surname
}

public_json_output(info)
