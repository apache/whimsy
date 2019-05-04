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

# Front sections:
# * Call to Order
# * Roll Call

class ASF::Board::Agenda
  parse do
    pattern = /
      ^\n\x20(?<section>[12]\.)
      \s(?<title>.*?)\n\n+
      (?<text>.*?)
      (?=\n\s[23]\.)
    /mx

    scan @file, pattern do |attr|
      if attr['title'] == 'Roll Call'
        attr['people'] = {}
        list = nil

        absent = attr['text'].scan(/Absent:\n\n.*?\n\n/m).join
        directors = attr['text'].scan(/^ +Directors[ \S]*?:\n\n.*?\n\n/m).join
        officers = attr['text'].scan(/^ +Executive[ \S]*?:\n\n.*?\n\n/m).join

        # attempt to identify the people mentioned in the Roll Call
        people = attr['text'].scan(/^ {8}(\w.*)/).flatten.each do |name|
          next if name == 'none'
          # Remove (extraneous [comments in past board minutes
          name.gsub! /(\s*[\[(]|\s+-).*/, '' 
          name.strip!

          role = :guest
          role = :director if directors.include? name
          role = :officer if officers.include? name

          sort_name = name.sub(/\(.*\)\s*$/, '').split(' ').rotate(-1).join(' ')

          if @quick
            attr['people']['_' + name.gsub(/\W/, '_')] = {
              name: name,
              sortName: sort_name,
              role: role,
              attending: !absent.include?(name)
            }
          else
            # look up name
            search = ASF::Person.list("cn=#{name}")
            # if found, save results in the attributes
            if search.length == 1
              person = search.first

              attr['people'][person.id] = {
                name: name,
                sortName: sort_name,
                role: role,
                member: person.asf_member?,
                attending: !absent.include?(name)
              }
            else
              # If not found, fallback to @quick behavior; WHIMSY-189
              attr['people']['_' + name.gsub(/\W/, '_')] = {
                name: name,
                sortName: sort_name,
                role: role,
                attending: !absent.include?(name)
              }
            end
          end
        end

        if attr['people']
          attr['people'] = Hash[attr['people'].
            sort_by {|id, person| person[:sortName]}]
        end
      elsif attr['title'] == 'Call to order'
        attr['timestamp'] = timestamp(attr['text'][/\d+:\d+([ap]m)?/])
      end
    end
  end
end
