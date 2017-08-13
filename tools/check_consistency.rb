#!/usr/bin/env ruby

# basic check of LDAP consistency
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
require 'whimsy/asf'

fix = ARGV.delete '--fix'

ASF::LDAP.bind if fix

auth_path=ARGV.shift

groups = ASF::Group.preload # for performance
committees = ASF::Committee.preload # for performance

projects = ASF::Project.preload
summary=Hash.new { |h, k| h[k] = { } }
projects.keys.each do |entry|
  summary[entry.name]['p']=1
end

puts "project.members ~ group.members"
groups.keys.sort_by {|a| a.name}.each do |entry|
    summary[entry.name]['g']=1
    project = ASF::Project[entry.name]
    if project
      p = []
      project.members.sort_by {|a| a.name}.each do |e|
          p << e.name
      end
      g = []
      entry.members.sort_by {|a| a.name}.each do |e|
          g << e.name
      end
      if p != g
        puts "#{entry.name}: pm-g=#{p-g} g-pm=#{g-p}" 

        if fix
          project.add_members(entry.members-project.members) unless (g-p).empty?
          project.remove_members(project.members-entry.members) unless (p-g).empty?
        end
      end
    end
end

puts ""
puts "project.owners ~ committee.members"
committees.keys.sort_by {|a| a.name}.each do |entry|
    summary[entry.name]['c']=1
    project = ASF::Project[entry.name]
    if project
      p = []
      project.owners.sort_by {|a| a.name}.each do |e|
          p << e.name
      end
      c = []
      entry.members.sort_by {|a| a.name}.each do |e|
          c << e.name
      end
      if p != c
        puts "#{entry.name}: po-c=#{p-c} c-po=#{c-p}" 

        if fix
          project.add_owners(entry.members-project.owners) unless (c-p).empty?
          project.remove_owners(project.owners-entry.members) unless (p-c).empty?
        end
      end
    end
end

puts ""
puts "current podlings(asf-auth) ~ project(members, owners)"
pods = Hash[ASF::Podling.list.map {|podling| [podling.name, podling.status]}]
# flag current podlings to show what records they have
pods.each do |name,status|
  summary[name]['pod'] = status if status == 'current'
end
# Scan the local defines and report differences
ASF::Authorization.new('asf',auth_path).each do |grp, mem|
  summary[grp]['pod'] = pods[grp] + ' (has local definition)'
  if pods[grp] == 'current'
    mem.sort!.uniq!
    project = ASF::Project[grp]
    if project
      pm = []
      project.members.sort_by {|a| a.name}.each do |e|
          pm << e.name
      end
      po = []
      project.owners.sort_by {|a| a.name}.each do |e|
          po << e.name
      end
      if mem != pm
        puts "#{grp}: pm-auth=#{pm-mem} auth-pm=#{mem-pm}" 
      end
      if mem != po
        puts "#{grp}: po-auth=#{po-mem} auth-po=#{mem-po}" 
      end
    end
  end
end
# Show where names are defined
puts "\nSummary of name definitions (proj,grp,cttee,status)"
def show(v,k)
  v[k] == 1 ? k : '-'
end
summary.sort.map do |k,v|
  puts "#{k.ljust(30)} #{show(v,'p')} #{show(v,'g')} #{show(v,'c')} #{v['pod'] rescue ''}"
end