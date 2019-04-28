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

# Minutes from previous meetings


class ASF::Board::Agenda
  # Must be outside scan loop
  FOUNDATION_BOARD = ASF::SVN.find('foundation_board') # Use find to placate Travis
  parse do
    minutes = @file.split(/^ 3. Minutes from previous meetings/,2).last.
      split(OFFICER_SEPARATOR,2).first

    pattern = /
      \s{4}(?<section>[A-Z])\.
      \sThe.meeting.of\s+(?<title>.*?)\n
      (?<text>.*?)
      \[\s(?:.*?):\s*?(?<approved>.*?)
      \s*comments:(?<comments>.*?)\n
      \s{8,9}\]\n
    /mx

    scan minutes, pattern do |attrs|
      attrs['section'] = '3' + attrs['section'] 
      attrs['text'] = attrs['text'].strip
      attrs['approved'] = attrs['approved'].strip.gsub(/\s+/, ' ')

      if FOUNDATION_BOARD
        file = attrs['text'][/board_minutes[_\d]+\.txt/].untaint
        if file and File.exist?(File.join(FOUNDATION_BOARD, file))
          attrs['mtime'] = File.mtime(File.join(FOUNDATION_BOARD, file)).to_i
        end
      end
    end
  end
end
