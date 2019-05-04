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
# Discussion Items
#

class ASF::Board::Agenda
  parse do
    discussion = @file.split(/^ \d. Discussion Items\n/,2).last.
      split(/^ \d. .*Action Items/,2).first
    
    if discussion !~ /\A\s{3,5}[0-9A-Z]\.\s/

      # One (possibly empty) item for all Discussion Items

      pattern = /
        ^(?<attach>\s[8]\.)
        \s(?<title>.*?)\n
        (?<text>.*?)
        (?=\n[\s1]\d\.|\n===)
      /mx

      scan @file, pattern do |attrs|
        attrs['attach'].strip!
        attrs['prior_reports'] = minutes(attrs['title'])
      end

    else

      # Separate items for each individual Discussion Item

      pattern = /
        \n+(?<indent>\s{3,5})(?<section>[0-9A-Z])\.
        \s(?<title>.*?)\n
        (?<text>.*?)
        (?=\n\s{3,5}[0-9A-Z]\.\s|\z)
      /mx

      scan discussion, pattern do |attrs|
        attrs['section'] = '8' + attrs['section'] 
      end
    end
  end
end
