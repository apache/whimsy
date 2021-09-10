# Creates JSON output with the following format:
#
# {
#   "lastCreateTimestamp": "20210908200129Z",
#   "people_count": 1234,
#   "people": {
#     "uid": {
#       "name": "Public Name",
#       "noLogin": true // present only if the login is not valid
#       "key_fingerprints": [ // if any are provided
#           "abcd xxxx xxxx xxxx xxxx", ...
#       ]
#     }
#     ...
# }
#

require_relative 'public_json_common'

# ASF people
peo = {}

peeps = ASF::Person.preload(['cn', 'loginShell', 'asf-personalURL', 'createTimestamp', 'modifyTimestamp', 'asf-pgpKeyFingerprint']) # for performance

if peeps.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

# Make output smaller by omitting commonest case (noLogin: false)
def makeEntry(hash, e)
  hash[e.id] = {
      name: e.public_name,
      createTimestamp:  e.createTimestamp,
  }
  if e.banned?
    hash[e.id][:noLogin] = true
  else
    # Don't publish urls for banned logins
    unless e.urls.empty?
      # need to sort to avoid random changes which seem to occur for urls
      hash[e.id][:urls] = e.urls.sort
    end
    # only add entry if there is a fingerprint
    unless e.pgp_key_fingerprints.empty?
      # need to sort to avoid random changes which seem to occur for fingerprints
      hash[e.id][:key_fingerprints] = e.pgp_key_fingerprints.sort
    end
  end
end

lastmodifyTimestamp = ''
lastcreateTimestamp = ''

peeps.sort_by(&:name).each do |e|
  next if e.id == 'apldaptest' # not a valid person
  makeEntry(peo, e)
  createTimestamp = e.createTimestamp
  if createTimestamp > lastcreateTimestamp
    lastcreateTimestamp = createTimestamp
  end
  modifyTimestamp = e.modifyTimestamp
  if modifyTimestamp > lastmodifyTimestamp
    lastmodifyTimestamp = modifyTimestamp
  end
end

info = {
  lastCreateTimestamp: lastcreateTimestamp,
#  This field has been disabled because it changes much more frequently than expected
#  This means that the file is flagged as having changed even when no other content has
#  lastTimestamp: lastmodifyTimestamp, # other public json files use this name
  people_count: peo.size,
  people: peo,
}

public_json_output(info)

# detect dropped names; these should not normally occur
if changed? and @old_file
  # Note: symbolize_names=false to avoid symbolising variable keys such as pmc and user names
  # However the current JSON (info) uses symbols for fixed keys - beware!
  previous = JSON.parse(@old_file, :symbolize_names=>false)
  now = info[:people].keys
  old = previous['people'].keys
  diff = old - now
  unless diff.empty?
    Wunderbar.warn "Unexpected removal of following names: #{diff}"
  end
end
