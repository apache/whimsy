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

ldap = ASF.init_ldap
exit 1 unless ldap

# ASF people
peo = {}

peeps = ASF::Person.preload(['cn', 'loginShell']) # for performance

# Make output smaller by ommitting commonest case (noLogin: false)
def makeEntry(hash, e)
  if e.banned?
    hash[e.id] = {
        name: e.public_name,
        noLogin: true
    }
  else
    hash[e.id] = {
        name: e.public_name,
    }
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
