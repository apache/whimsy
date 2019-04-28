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
# Post list of action items
#

Agenda.update(@agenda, @message) do |agenda|
  # render all uncompleted actions
  text = ''
  @actions.each do |action|
    next if action['complete']

    # reflow lines
    lines = "* #{action['owner']}: #{action['text']}".reflow(0, 78).split("\n")
    text += lines.shift + "\n"
    text += lines.join("\n").reflow(6, 72) + "\n" unless lines.empty?

    # add pmc, date, if present
    if not action['pmc'].to_s.empty?
      if not action['date'].to_s.empty?
        text += "      [ #{action['pmc']} #{action['date']} ]\n"
      else
        text += "      [ #{action['pmc']} ]\n"
      end
    elsif not action['date'].to_s.empty?
      text += "      [ #{action['date']} ]\n"
    end

    # add pmc, date, if present
    text += "      Status:\n\n"
  end

  # insert into the agenda
  agenda[/^\s+\d+\.\sReview\sOutstanding\s Action\s Items\n(\s*\n)
    \s*\d+\.\sUnfinished\sBusiness/x, 1] = "\n" + text.gsub(/^(.)/, '    \1')

  # return updated agenda
  agenda
end
