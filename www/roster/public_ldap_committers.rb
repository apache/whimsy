# Use to create JSON output with the following format:
#
#  NO LONGER USED, please see public-ldap-groups (committers) and public-ldap-people instead
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

require_relative 'public_json_common'

info = {
    comment: "Please use public-ldap-groups (committers) and public-ldap-people instead"
}

public_json_output(info)
