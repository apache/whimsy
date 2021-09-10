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
#       ],
#      "podling": "current" // optional status if same as a podling name
#     }
#   },
# }

require_relative 'public_json_common'

pods = ASF::Podling.list.map {|podling| [podling.name, podling.status]}.to_h

groups = {}

# find the locally defined groups
ASF::Authorization.new('asf').each do |grp, mem|
  groups[grp] = {
      # we use same syntax as for normal groups
      # this will allow future expansion e.g. if we can flag podlings somehow
      roster: mem.sort.uniq
      }
  # add podling type entry if there is one
  groups[grp][:podling] = pods[grp] if pods[grp]
end

# Not currently used
#pitgroups = {}
#
## find the locally defined groups
#ASF::Authorization.new('pit').each do |grp, mem|
#  pitgroups[grp] = {
#      # we use same syntax as for normal groups
#      # this will allow future expansion e.g. if we can flag podlings somehow
#      roster: mem.sort.uniq
#      }
#  # add podling type entry if there is one
#  pitgroups[grp][:podling] = pods[grp] if pods[grp]
#end

public_json_output(
  # There does not seem to be a useful timestamp here
  groups: groups
  # TODO decide how to present the data: separate key or attribute or file
  #pitgroups: pitgroups
)

if changed? and @old_file
  # for validating UIDs
  uids = ASF::Person.list().map(&:id)
  groups.each do |name, entry|
    entry[:roster].each do |id|
      Wunderbar.warn "#{name}: unknown uid '#{id}'" unless uids.include?(id)
    end
  end
end
