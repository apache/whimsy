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

#
# Helpers for building agenda items to be posted:
#  committee-list: list all of the committees
#  committee-members: list chair and members of a committee
#  change-chair: produce a draft change chair resolution
#

# debugging support: enable script to be run from the command line
if $0 == __FILE__
  $LOAD_PATH.unshift '/srv/whimsy/lib'
  Dir.chdir File.expand_path('../..', __dir__)
  require './helpers/string'
  require 'whimsy/asf'
  require 'erubis'
  require 'ostruct'
  require 'pp'
  $SAFE = 1

  ARGV.each do |arg|
    name, value = arg.split('=', 2)
    next unless name =~ /^\w+$/ and value
    instance_variable_set "@#{name}", value
  end

  binding.local_variable_set :env, OpenStruct.new(user: ENV['user'])
end

ASF::Committee.load_committee_info

output = case @request
when 'committee-list'
  id = env.user

  committees = {chair: [], member: [], rest: []}
           
  ASF::Committee.pmcs.sort_by {|pmc| pmc.id}.each do |pmc|
    if pmc.chairs.any? {|chair| chair[:id] == id}
      committees[:chair] << pmc.id
    elsif pmc.info.include? 'rubys'
      committees[:member] << pmc.id
    else 
      committees[:rest] << pmc.id
    end
  end 
      
  committees[:chair] + committees[:member] + committees[:rest]

when 'committee-members'
  committee = ASF::Committee[@pmc]
  return unless committee
  chair = committee.chairs.first
  return unless chair
  roster = committee.roster
  roster.delete(chair[:id])

  roster = roster.map {|id, info| {id: id}.merge(info)}

  {chair: chair, members: roster}

when 'change-chair'
  @committee = ASF::Committee[@pmc]
  return unless @committee
  @outgoing_chair = ASF::Person[@committee.chairs.first[:id]]
  @incoming_chair = ASF::Person[@chair]
  return unless @outgoing_chair and @incoming_chair

  template = File.read('templates/change-chair.erb').untaint
  draft = Erubis::Eruby.new(template).result(binding)

  {draft: draft.reflow(0, 71)}

when 'establish'
  @people = @people.split(',').map {|id| ASF::Person[id]}
  @people.sort_by! {|person| ASF::Person.sortable_name(person.public_name)}
  @description = @description.strip.sub(/\.\z/, '')
  @chair = ASF::Person[@chair]
  @pmcname.gsub!(/\b\w/) {|c| c.upcase} unless @pmcname =~ /[A-Z]/

  template = File.read('templates/establish.erb').untaint
  draft = Erubis::Eruby.new(template).result(binding)
  names = draft[/^(\s*\*.*\n)+/]
  if names
    draft[/^(\s*\*.*\n)+/] = "\n<-@->\n"
    draft = draft.reflow(0, 71)
    draft.sub! "\n<-@->\n", names
  else
    draft = draft.reflow(0, 71)
  end

  {draft: draft, names: names}

when 'terminate'
  @committee = ASF::Committee[@pmc]
  return unless @committee

  template = File.read('templates/terminate.erb').untaint
  draft = Erubis::Eruby.new(template).result(binding)

  {draft: draft.reflow(0, 71)}
end

puts output if $0 == __FILE__

output
