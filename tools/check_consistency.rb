# basic check of LDAP consistency
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
require 'whimsy/asf'

groups = ASF::Group.preload # for performance
committees = ASF::Committee.preload # for performance
projects = ASF::Project.preload

puts "project.members ~ group.members"
groups.keys.sort_by {|a| a.name}.each do |entry|
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
      end
    end
end

puts ""
puts "project.owners ~ committee.members"
committees.keys.sort_by {|a| a.name}.each do |entry|
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
      end
    end
end
