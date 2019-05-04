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

# Attachments

class ASF::Board::Agenda
  parse do
    pattern = /
      -{41}\n
      Attachment\s\s?(?<attach>\w+):\s(?<title>.*?)\n+
      (?<report>.*?)
      (?=-{41,}\n(?:End|Attach))
    /mx

    scan @file, pattern do |attrs|

      # join multiline titles
      while attrs['report'].start_with? '        '
        append, attrs['report'] = attrs['report'].split("\n", 2)
        attrs['title'] += ' ' + append.strip
      end

      attrs['title'].sub! /^Report from the VP of /, ''
      attrs['title'].sub! /^Report from the /, ''
      attrs['title'].sub! /^Status report for the /, ''
      attrs['title'].sub! /^Apache /, ''
      attrs['title'].sub! 'Apache Software Foundation', 'ASF'

      if attrs['title'] =~ /\s*\[.*\]$/
        attrs['owner'] = attrs['title'][/\[(.*?)\]/, 1]
        attrs['title'].sub! /\s*\[.*\]$/, ''
      end

      attrs['title'].sub! /\sTeam$/, ''
      attrs['title'].sub! /\sCommittee$/, ''
      attrs['title'].sub! /\sProject$/, ''

      attrs['digest'] = Digest::MD5.hexdigest(attrs['report'].strip)

      attrs['report'].sub! /\n+\Z/, "\n"
      attrs.delete('report') if attrs['report'] == "\n"

      attrs['missing'] = true if attrs['report'].strip.empty?

      unless @quick
        begin
          committee = ASF::Committee.find(attrs['title'])
          attrs['chair_email'] = "#{committee.chair.id}@apache.org"
          attrs['mail_list'] = committee.mail_list
          attrs.delete('mail_list') if attrs['mail_list'].include? ' '

          attrs['notes'] = $1 if committee.report =~ /^Next month: (.*)/
        rescue
        end
      end

      if attrs['report'].to_s.include? "\uFFFD"
        attrs['warnings'] = ['UTF-8 encoding error']
      end
    end
  end
end
