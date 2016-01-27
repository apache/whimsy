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
#     "batchee": {
#       "roster": [
#         "uid",
#          ...
#       ]
#     }
#   },
# }

require_relative 'public_json_common'

require 'net/http'

file = '/apache/infrastructure-puppet/deployment/modules/subversion_server/files/authorization/asf-authorization-template'
http = Net::HTTP.new('raw.githubusercontent.com', 443)
http.use_ssl = true
body = http.request(Net::HTTP::Get.new(file)).body
  .sub(/^.*\[groups\]\s*$/m,'')
  .sub(/^\[\/\].*/m,'')

groups = {}

# find the locally defined groups
body.scan(/^(\w[^=\s]*)[ \t]*=[ \t]*(\w.*)$/) do |grp, mem|
  groups[grp] = {
      # we use same syntax as for normal groups
      # this will allow future expansion e.g. if we can flag podlings somehow
      roster: mem.gsub(/\s/,'').split(/,/).sort.uniq
      }
end

public_json_output(
  # There does not seem to be a useful timestamp here
  groups: groups,
)
