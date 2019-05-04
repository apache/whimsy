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

require 'weakref'

module ASF

  class Person < Base
  
    # Return a hash of nominated members.  Keys are ASF::Person objects,
    # values are the nomination text.
    def self.member_nominees
      begin
        return Hash[@member_nominees.to_a] if @member_nominees
      rescue
      end

      meetings = ASF::SVN['Meetings']
      nominations = Dir[File.join(meetings, '*', 'nominated-members.txt')].sort.last.untaint

      nominations = File.read(nominations).split(/^\s*---+--\s*/)
      nominations.shift(2)

      nominees = {}
      nominations.each do |nomination|
        id = nomination[/^\s?\w+.*<(\S+)@apache.org>/,1]
        id ||= nomination[/^\s?\w+.*\((\S+)@apache.org\)/,1]
        id ||= nomination[/^\s?\w+.*\(([a-z]+)\)/,1]

        next unless id

        nominees[find(id)] = nomination
      end

      @member_nominees = WeakRef.new(nominees)
      nominees
    end

    # Return the member nomination text for this individual
    def member_nomination
      @member_nomination ||= Person.member_nominees[self]
    end
  end
end
