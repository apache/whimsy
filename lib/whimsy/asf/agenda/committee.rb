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

# Additional Officer Reports and Committee Reports

class ASF::Board::Agenda
  parse do
    pattern = /
      \[(?<owner>[^\n]+)\]\n\n
      \s{7}See\sAttachment\s\s?(?<attach>\w+)[^\n]*?\s+
      \[\s[^\n]*\s*approved:\s*?(?<approved>.*?)
      \s*comments:(?<comments>.*?)\n\s{9}\]
    /mx

    scan @file, pattern do |attrs|
      attrs['shepherd'] = attrs['owner'].split('/').last.strip
      attrs['owner'] = attrs['owner'].split('/').first.strip

      attrs['comments'].gsub! /^ {1,10}(\w+:)/, '\1'
      attrs['comments'].gsub! /^ {11}/, ''
    end
  end
end
