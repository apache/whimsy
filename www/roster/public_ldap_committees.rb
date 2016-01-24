# Creates JSON output with the following format:
#
# {
#   "lastTimestamp": "20160119171152Z", // most recent modifyTimestamp
#   "committees": {
#     "abdera": {
#       "modifyTimestamp": "20111204095436Z",
#       "roster": ["uid",
#       ...
#       ]
#     },
#     ...
#   },
# }
#

require 'bundler/setup'

require 'whimsy/asf'

require 'open3'

GITINFO = ASF.library_gitinfo rescue '?'

ldap = ASF.init_ldap
exit 1 unless ldap

# gather committee info
entries = {}

committees = ASF::Committee.preload # for performance

lastStamp = ''
committees.keys.sort_by {|a| a.name}.each do |entry|
    m = []
    entry.members.sort_by {|a| a.name}.each do |e|
        m << e.name
    end
    lastStamp = entry.modifyTimestamp if entry.modifyTimestamp > lastStamp
    entries[entry.name] = {
        modifyTimestamp: entry.modifyTimestamp,
        roster: m 
    }
end

info = {
  lastTimestamp: lastStamp,
  committees: entries,
}

# format as JSON
results = JSON.pretty_generate(info)

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  # write to STDOUT
  puts results
elsif not File.exist?(ARGV.first) or File.read(ARGV.first) != results
  puts "git_info: #{GITINFO}"
  out, err, rc = Open3.capture3('diff', '-u', ARGV.first, '-', stdin_data: results)
  puts out if err.empty? and rc.exitstatus == 1

  # replace file as contents have changed
  File.write(ARGV.first, results)
else
  puts "git_info: #{GITINFO}"
end
