# Creates JSON output with the following format:
#
# {
#   "committers": {
#     "uid": {
#       "name": "Public Name",
#       "noLogin": true // present only if the login is not valid
#     }
#     ...
#   },
#   "non_committers": { // entries in 'ou=people,dc=apache,dc=org' who are not committers
#     "uid": {
#       "name": "Public Name",
#       "noLogin": true // present only if the login is not valid
#     }
#     ...
#   },
# }
#

require 'bundler/setup'

require 'whimsy/asf'

GITINFO = ASF.library_gitinfo rescue '?'

ldap = ASF.init_ldap
exit 1 unless ldap

# ASF committers
com = {}
# people entries that are not committers
peo = {}

comms = ASF.committers
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

# List each ASF committer group member 
comms.sort_by {|a| a.id}.each do |e|
  makeEntry(com, e)
end

# Now see if there are any left-over people
peeps.sort_by {|a| a.name}.each do |e|
  unless comms.include? e
    makeEntry(peo, e)
  end
end

info = {
  # There does not seem to be a useful timestamp here
  committers: com,
  non_committers: peo,
}

# format as JSON
results = JSON.pretty_generate(info)

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  # write to STDOUT
  puts results
elsif not File.exist?(ARGV.first) or File.read(ARGV.first) != results
  puts "git_info: #{GITINFO}"
  # replace file as contents have changed
  File.write(ARGV.first, results)
else
  puts "git_info: #{GITINFO}"
end
