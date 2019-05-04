##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#!/usr/bin/env ruby
PAGETITLE = "Incubator/Podling crosscheck" # Wvisible:incubator

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

def get_data(defaults: {})
  return {
    "Sample data processing here" => "row 1",
    "This could come from a file" => "row B"
  }
end

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png" => "Incubator Logo, to show that graphics can appear",
        "https://community.apache.org/" => "Get Community Help",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p! do
          _ 'This script cross-checks '
          _a 'Incubator PMC lists in LDAP',
            href: '../../roster/committee/incubator'
          _ ', '
          _a 'mentor lists in podlings.xml',
            href: 'https://svn.apache.org/repos/asf/incubator/public/trunk/content/podlings.xml'
          _ ',  and '
          _a 'Podling lists in LDAP',
            href: '../../roster/ppmc'
          _ '.'
        end
      }
    ) do


      ASF.init_ldap

      ipmc = ASF::Project.find('incubator').owners
      incubator = ASF::Project.find('incubator').members

      podlings = ASF::Podling.current.map {|podling| podling.id}
      podling_committers = ASF::Project.preload.
        select {|project, members| podlings.include? project.name}.
        map {|project,members| project.members}.flatten.uniq

      #
      ### Podling mentors vs IPMC
      #
      _whimsy_panel_table(
        title: "Podling Mentors that are not IPMC members",
      ) do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Podling'
              _th 'Mentor'
            end
            _tbody do
              ASF::Podling.list.each do |podling|
                next unless podling.status == 'current'
                mentors = podling.mentors.map {|id| ASF::Person.find(id)}
                orphans = podling.members - incubator
                unless orphans.empty?
                  orphans.each do |person|
                    if 
                      podling.mentors.include? person.id
                    then
                      _tr_ do
                        _td do
                          _a podling.display_name, 
                            href: "../../roster/ppmc/#{podling.id}"
                        end
                        _td do
                          if person.asf_member?
                            _b do
                              _a person.public_name,
                                href: "../../roster/committer/#{person.id}"
                            end
                          else
                            _a person.public_name,
                              href: "../../roster/committer/#{person.id}"
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      #
      ### PPMC committers vs incubator committers 
      #
      _whimsy_panel_table(
        title: "Podling Committers that are not Incubator committers",
      ) do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Podling'
              _th 'Committer'
            end
            _tbody do
              ASF::Podling.list.each do |podling|
                next unless podling.status == 'current'
                mentors = podling.mentors.map {|id| ASF::Person.find(id)}
                orphans = podling.members - incubator
                unless orphans.empty?
                  orphans.each do |person|
                    if 
                      not podling.mentors.include? person.id
                    then
                      _tr_ do
                        _td do
                          _a podling.display_name, 
                            href: "../../roster/ppmc/#{podling.id}"
                        end
                        _td do
                          if person.asf_member?
                            _b do
                              _a person.public_name,
                                href: "../../roster/committer/#{person.id}"
                            end
                          else
                            _a person.public_name,
                              href: "../../roster/committer/#{person.id}"
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      #
      ### Incubator committers vs Podling committers
      #
      _whimsy_panel_table(
        title: "Incubator committers that are not on the IPMC and are not 
                listed as a committer of any podling"
      ) do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Committer'
            end
            _tbody do
              incubator.sort_by {|person| person.public_name}.each do |person|
                next if ipmc.include? person
                next if podling_committers.include? person
                _tr_ do
                  _td do
                    if person.asf_member?
                      _b do
                        _a person.public_name,
                       href: "../../roster/committer/#{person.id}"
                      end
                    else
                      _a person.public_name,
                        href: "../../roster/committer/#{person.id}"
                    end
                  end
                end
              end
            end
          end
        end
      end

    end
  end
end
