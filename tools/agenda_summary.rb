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
# Parse board meeting minutes and emit statistics
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'whimsy/asf/agenda'
require 'json'
require 'set'

BOARD = ASF::SVN['foundation_board']
STATS_ROLLUP = 'stats'

# Create summary of statistics from 2007->up board minutes (includes private data)
# Note that for F2F meetings or meetings before preapps, this won't parse reliably
# @param dir pointing to /foundation/board/archived_agendas
# @return stats hash of of various statistics from minutes
def summarize_all(dir = BOARD)
  summaries = Hash.new{|h,k| h[k] = {} }
  Dir[File.join(dir, 'archived_agendas', "board_agenda_2*.txt")].sort.each do |f|
      summaries[File.basename(f, '.*')] = ASF::Board::Agenda.summarize(f)
  end
  allpmcs = Set.new()
  allpeople = Set.new()
  summaries.each do |month, summary|
    if summary['pmcs']
      summary['pmcs'].each do |title, data|
        allpmcs << title
      end
    end
    if summary['people']
      summary['people'].each do |id, pers|
        allpeople << pers[:name] # Note: some keys are symbols from ASF::Board::Agenda.parse
      end
    end
  end
  summaries[STATS_ROLLUP]['allpmcs'] = allpmcs.to_a
  summaries[STATS_ROLLUP]['allpeople'] = allpeople.to_a
  return summaries
end

#### Main method - process default files and output JSON
outfile = "meeting-summary.json"
summaries = summarize_all()
File.open(outfile, "w") do |f|
  f.puts JSON.pretty_generate(summaries)
end
puts "DONE: emitted #{outfile}"
