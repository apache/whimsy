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

# Back sections:
# * Review Outstanding Action Items
# * Unfinished Business
# * New Business
# * Announcements
# * Adjournment

class ASF::Board::Agenda
  parse do
    pattern = /
      ^(?<attach>(?:\s9|1\d)\.)
      \s(?<title>.*?)\n
      (?<text>.*?)
      (?=\n[\s1]\d\.|\n===)
    /mx

    scan @file, pattern do |attrs|
      attrs['attach'].strip!
      attrs['title'].sub! /^Review Outstanding /, ''

      if attrs['title'] =~ /Discussion|Action|Business|Announcements/
        attrs['prior_reports'] = minutes(attrs['title'])
      elsif attrs['title'] == 'Adjournment'
        attrs['timestamp'] = timestamp(attrs['text'][/\d+:\d+([ap]m)?/])
      end

      if attrs['title'] =~ /Action Items/

        # extract action items associated with projects
        text = attrs['text'].sub(/\A\s*\n/, '').sub(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min || 1
        text.gsub! /^ {#{unindent-1}}/, ''

        attrs['missing'] = text.empty?

        attrs['actions'] = text.sub(/^\* /, '').split(/^\n\* /).map do |text|
          match1 = /(.*?)(\n\s*Status:(.*))/m.match(text)
          if match1
            match2 = /(.*?)(\[ ([^\]]+) \])?\s*\Z/m.match(match1[1])
            match3 = /(.*?): (.*)\Z/m.match(match2[1])
            match4 = /(.*?)( (\d+-\d+-\d+))?$/.match(match2[3])
            { 
              owner: match3[1],
              text: match3[2].strip,
              status: match1[3].to_s.strip,
              pmc: (match4[1] if match4), 
              date: (match4[3] if match4)
            }
          else # Just copy text for items with no Status: see WHIMSY-187
            { 
              owner: '',
              text: text.strip,
              status: '',
              pmc: '', 
              date: ''
            }
          end
        end
      end
    end
  end
end
