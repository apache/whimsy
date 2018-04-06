#
# Helpers for building agenda items to be posted:
#  committee-list: list all of the committees
#  committee-members: list chair and members of a committee
#  change-chair: produce a draft change chair resolution
#

# debugging support: enable script to be run from the command line
if $0 == __FILE__
  $LOAD_PATH.unshift File.realpath(File.expand_path('../'*6 + 'lib', __FILE__))
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
      
  committees[:chair] + committees[:member] + committees[:rest] + [@request]

when 'committee-members'
  committee = ASF::Committee.find(@pmc)
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

when 'terminate'
  @committee = ASF::Committee[@pmc]
  return unless @committee

  template = File.read('templates/terminate.erb').untaint
  draft = Erubis::Eruby.new(template).result(binding)

  {draft: draft.reflow(0, 71)}
end

puts output if $0 == __FILE__

output
