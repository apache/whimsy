# Creates JSON output with the following format:
#
# {
#   "last_updated": "2016-01-20 00:47:45 UTC",
#   "git_info": "9d1cefc  2016-01-22T11:44:14+00:00",
#   "committees": {
#     "abdera": [
#       "uid",
#       ...
#     ],
#     ...
#   },
# }
#

require 'bundler/setup'

require 'whimsy/asf'

GITINFO = ASF.library_gitinfo rescue '?'

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  output = STDOUT
else
  output = File.open(ARGV.first, 'w')
end

ldap = ASF.init_ldap
exit 1 unless ldap

# gather committer info
entries = {}

ASF::Committee.list.sort_by {|a| a.name}.each do |entry|
    m = []
    entry.members.sort_by {|a| a.name}.each do |e|
        m << e.name
    end
    entries[entry.name] = m
end

info = {
  last_updated: ASF::ICLA.svn_change,
  git_info: GITINFO,
  committees: entries,
}

# output results
output.puts JSON.pretty_generate(info)
output.close

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
