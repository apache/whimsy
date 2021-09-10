# Extract public mailing list data in the form:
#
# {
#   "last_updated": "2021-02-25 22:33:27 +0000",
#   "list_data": [
#     [
#       "abdera.apache.org", // this was retired
#       {
#         "commits": false,
#         "dev": false,
#         "user": false
#       }
#     ],
#     [
#       "accumulo.apache.org", // active
#       {
#         "commits": true,
#         "dev": true,
#         "notifications": true,
#         "user": true
#       }
#     ],


require_relative 'public_json_common'
require 'whimsy/asf/mlist'
require '/srv/whimsy/tools/ponyapi'

info = {
  last_updated: Time.now,
}

data = {}

# which lists are currently active
active_lists = Set.new
ASF::MLIST.each_list do |dom, list|
  active_lists << [dom, list]
end

PonyAPI.get_pony_lists(nil, nil, true).each do |dom, lists|
  data[dom] = {}
  lists.keys.sort.each do |list|
    data[dom][list] = active_lists.include? [dom, list]
  end
end

info[:list_count] = data.size
# TODO probably not worth summarising domains
info[:lists] = data.sort.to_h # sort to ensure only valid changes are reported

public_json_output(info)
