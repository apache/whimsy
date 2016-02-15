# Creates JSON output with the following format:
#
# {
#   "people": {
#     "uid": {
#       "name": "Public Name",
#       "noLogin": true // present only if the login is not valid
#     }
#     ...
# }
#

require 'bundler/setup'

require_relative 'public_json_common'

require 'whimsy/asf'

# ASF people
peo = {}

peeps = ASF::Person.preload(['cn', 'loginShell']) # for performance

if peeps.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

# Make output smaller by ommitting commonest case (noLogin: false)
def makeEntry(hash, e)
  hash[e.id] = {
      name: e.public_name,
  }
  if e.banned?
    hash[e.id][:noLogin] = true
  end
end

peeps.sort_by {|a| a.name}.each do |e|
    makeEntry(peo, e)
end

info = {
  # There does not seem to be a useful timestamp here
  people: peo,
}

public_json_output(info)
