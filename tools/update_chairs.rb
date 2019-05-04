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

# @(#) Script to update foundation/index.txt list of chars from committee-info.json

# Must be run locally at present, and the changes checked in manually

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'json'
require 'open-uri'
require 'whimsy/asf'

cttees=JSON.parse(open('https://whimsy.apache.org/public/committee-info.json').read)['committees']
chairs={}
cttees.reject{|k,v| v['pmc'] == false}.each do|k,v|
    cttee=v['display_name']
    chairs[cttee]=v['chair'].first[1]['name']
end

idx=File.join(ASF::SVN['site-root'],'foundation','index.mdtext')

puts "Updating #{idx} to latest copy"
puts `svn update #{idx}`

puts "Checking if any changes are needed"
lines=[]
first=nil # first line of chairs
last=nil
changes=[]
seen=Hash.new{|h,k| h[k]=0}
open(idx).each_line do |l|
#   | V.P., Apache Xalan | A. N. Other |
    m = l.match %r{^\| V.P., \[?Apache (.+?)(\]\(.+?\))? \| (.+?) \|}
    if m
       first ||= lines.length
       last = lines.length
       name,_,webchair = m.captures
       cichair = chairs[name]
       seen[name] += 1
       unless cichair
         puts "Cannot find CI entry for #{name}; dropping entry"
         changes << name
         next
       end
       if seen[name] > 1
        puts "Duplicate entry for #{name}; dropping"
        changes << name
        next
       end
       unless webchair == cichair
           puts "Changing chair for #{name} from #{webchair} to #{cichair}"
           lines << l.sub(webchair,cichair)
           changes << name
           next
       end
    end
    lines << l
end

notseen = (chairs.keys - seen.keys).sort
if notseen.length > 0
  puts "No entry found for: " + notseen.join(',')
  notseen.each do |e|
    puts "Adding #{e}"
    lines.insert last, "| V.P., Apache #{e} | #{chairs[e]} |\n"
    changes << e
  end
  # N.B. Cannot use sort! on slice
  lines[first..last+notseen.length] = lines[first..last+notseen.length].sort_by do |l| 
    l.match(/Apache +([^\]|]+)/) do |m| 
      $1.downcase.gsub(' ','')
    end
  end
end


if changes.length > 0
  puts "Updating the file"
  File.open(idx,"w") do |f|
      lines.each {|line| f.print line}
  end
  puts "#{idx} was updated; check the diffs:"
  puts `svn diff #{idx}`
  puts "Copy/paste the next line to commit the change:"
  puts "svn ci -m'Changed chairs for: #{changes.join(',')}' #{idx}"  
else
  puts "#{idx} not changed"
end