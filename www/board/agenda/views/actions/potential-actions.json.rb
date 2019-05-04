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
# potential actions
#

# get posted action items from previous report
base = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort[-2].untaint
parsed = ASF::Board::Agenda.parse(IO.read(base), true)
actions = parsed.find {|item| item['title'] == 'Action Items'}['actions']

# scan draft minutes for new action items
pattern = /^(?:@|AI\s+)(\w+):?\s+([\s\S]*?)(?:\n\n|$)/m
minutes = File.basename(base).sub('agenda', 'minutes').sub('.txt', '.yml')
date = minutes[/\d{4}_\d\d_\d\d/].gsub('_', '-')
minutes = YAML.load_file("#{AGENDA_WORK}/#{minutes}") rescue {}
minutes.each do |title, secnotes|
  next unless String === secnotes
  secnotes.scan(pattern).each do |owner, text|
    text = text.reflow(6, 72).strip
    actions << {owner: owner, text: text, status: nil, pmc: title, date: date}
  end
end

# get roll call info
roll = parsed.find {|item| item['title'] == 'Roll Call'}['people']

# return results
_date date
_actions actions
_names roll.map {|id, person| person[:name].split(' ').first}.sort.uniq
