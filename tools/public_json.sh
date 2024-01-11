#!/usr/bin/env bash

#  Licensed to the Apache Software Foundation (ASF under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"; you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# script to create the public JSON files
# Must be run as the apache user; normally done as cron jobs
set -v
cd /srv/whimsy/www || exit
ruby roster/public_committee_info.rb public/committee-info.json public/committee-retired.json > logs/public-committee-info 2>&1
ruby roster/public_icla_info.rb public/icla-info.json public/icla-info_noid.json > logs/public-icla-info 2>&1
ruby roster/public_ldap_authgroups.rb public/public_ldap_authgroups.json > logs/public-ldap-authgroups 2>&1
ruby roster/public_ldap_groups.rb public/public_ldap_groups.json > logs/public-ldap-groups 2>&1
ruby roster/public_ldap_people.rb public/public_ldap_people.json > logs/public-ldap-people 2>&1
ruby roster/public_ldap_projects.rb public/public_ldap_projects.json > logs/public-ldap-projects 2>&1
ruby roster/public_ldap_roles.rb public/public_ldap_roles.json > logs/public-ldap-roles 2>&1
ruby roster/public_ldap_services.rb public/public_ldap_services.json > logs/public-ldap-services 2>&1
ruby roster/public_member_info.rb public/member-info.json > logs/public-member-info 2>&1
ruby roster/public_nonldap_groups.rb public/public_nonldap_groups.json > logs/public-nonldap-groups 2>&1
ruby roster/public_podlings.rb public/public_podling_status.json public/public_podlings.json > logs/public-podlings 2>&1
