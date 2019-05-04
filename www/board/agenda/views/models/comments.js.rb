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
# Fetch, retain, and query the list of historical comments
#

class HistoricalComments
  Vue.util.defineReactive @@comments, nil

  # find historical comments based on report title
  def self.find(title)
    if @@comments
      return @@comments[title]
    else
      @@comments = {}
      JSONStorage.fetch('historical-comments') do |comments|
        @@comments = comments || {}
      end
    end
  end

  # find link for historical comments based on date and report title
  def self.link(date, title)
    if Server.agendas.include? "board_agenda_#{date}.txt"
      return "../#{date.gsub('_', '-')}/#{title}"
    else
      return "../../minutes/#{title}.html#minutes_#{date}"
    end
  end
end
