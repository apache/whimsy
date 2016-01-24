# Not all authorization groups are defined in LDAP, for example podlings
# Extract these from asf-authorization-template
#
# We use the Git copy rather than the SVN version:
# - it is available without needing auth
# - the groups don't take effect unless the Git copy is updated
# - the SVN copy is due to be retired (one day)
# Unfortunately the Git HTTP server does not support If-Modified-Since or ETag
#
# Output looks like:
# {
#   "groups": {
#     "batchee": [
#       "uid",
#       ...
#     ] 
#    },
# 

require 'bundler/setup'

require 'whimsy/asf'

require 'net/http'
require 'json'
require 'open3'

GITINFO = ASF.library_gitinfo rescue '?'

file = '/apache/infrastructure-puppet/deployment/modules/subversion_server/files/authorization/asf-authorization-template'
http = Net::HTTP.new('raw.githubusercontent.com', 443)
http.use_ssl = true
body = http.request(Net::HTTP::Get.new(file)).body
  .sub(/^.*\[groups\]\s*$/m,'')
  .sub(/^\[\/\].*/m,'')

groups = {}

# find the locally defined groups
body.scan(/^(\w[^=\s]*)[ \t]*=[ \t]*(\w.*)$/) do |grp, mem|
  groups[grp] = mem.gsub(/\s/,'').split(/,/).sort.uniq
end

info = {
  # There does not seem to be a useful timestamp here
  groups: groups,
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
