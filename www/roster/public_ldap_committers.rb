# Creates JSON output with the following format:
#
# {
#   "last_updated": "2016-01-20 00:47:45 UTC",
#   "git_info": "9d1cefc  2016-01-22T11:44:14+00:00",
#   "committers": { // committers who have valid login shells
#     "uid": "Public Name",
#     ...
#   },
#   "committers_nologin": { // committers with invalid login shells
#     "uid": "Public Name",
#     ...
#   },
#   "non_committers": { // entries in 'ou=people,dc=apache,dc=org' who are not committers but who can login
#     "uid": "Public Name",
#     ...
#   },
#   "non_committers_nologin": { // entries in 'ou=people,dc=apache,dc=org' who are not committers and have invalid shells
#     "uid": "Public Name",
#     ...
# }
#

require 'bundler/setup'

require 'whimsy/asf'

GITINFO = ASF.library_gitinfo rescue '?'

ldap = ASF.init_ldap
exit 1 unless ldap

# gather committer info
ids = {}
# banned or deceased or emeritus or ...
ban = {}
# people entries that are not committers (and not in nologin)
non = {}
# people entries that are not committers (in nologin)
nonb = {}

peeps = ASF::Person.preload(['cn', 'loginShell']) # for performance

peeps.sort_by {|a| a.id}.each do |entry|
    if entry.banned?
        ban[entry.id] = entry.public_name 
    else
        ids[entry.id] = entry.public_name 
    end
end

peeps.sort_by {|a| a.name}.each do |e|
  unless ASF.committers.include? e
     if e.banned?
         nonb[e.name] = e.public_name
     else
         non[e.name] = e.public_name
     end
  end
end

info = {
  last_updated: ASF::ICLA.svn_change,
  git_info: GITINFO,
  committers: ids,
  committers_nologin: ban,
  non_committers: non,
  non_committers_nologin: nonb,
}

# format as JSON
results = JSON.pretty_generate(info)

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  # write to STDOUT
  puts results
elsif not File.exist?(ARGV.first) or File.read(ARGV.first) != results
  # replace file as contents have changed
  File.write(ARGV.first, results)
end
