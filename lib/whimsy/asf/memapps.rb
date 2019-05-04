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
# Common access to membership application files
#

### INITIAL RELEASE - SUBJECT TO CHANGE ###

require_relative 'config'
require_relative 'svn'

module ASF
  class MemApps
    @@MEMAPPS = ASF::SVN['member_apps']
    @@files = nil
    @@mtime = nil

    # list the stems of the files (excluding any ones which record emeritus)
    def self.stems
      refresh
      apps = @@files.reject{|f| f =~ /_emeritus\.\w+$/}.map do |file|
        file.sub(/\.\w+$/, '')
      end
      apps
    end

    # list the names of the files (excluding any ones which record emeritus)
    def self.names
      refresh
      @@files.reject{|f| f =~ /_emeritus\.\w+$/}
    end

    # names of emeritus files
    def self.emeritus
      refresh
      apps = @@files.select {|f| f =~ /_emeritus\.\w+$/}.map do |file|
        file.sub(/_emeritus\.\w+$/, '')
      end
      apps
    end

    def self.sanitize(name)
      # Don't transform punctation into '-'
      ASF::Person.asciize(name.strip.downcase.gsub(/[.,()"]/,''))
    end

    def self.search(filename)
      names = self.names()
      if names.include?(filename)
        return filename
      end
      names.each { |name|
        if name.start_with?("#{filename}.")
          return name
        end
      }
      nil
    end

    # find the name of the memapp for a person or nil
    def self.find1st(person)
      self.find(person)[0].first
    end

    # find the memapp for a person; return an array:
    # - [array of files that matched (possibly empty), array of stems that were tried]
    def self.find(person)
      found=[] # matches we found
      names=[] # names we tried
      [
        (person.icla.legal_name rescue nil),
        (person.icla.name rescue nil),
        person.member_name # this is slow
      ].uniq.each do |name|
        next unless name
        memapp = self.sanitize(name) # this may generate dupes, so we use uniq below
        names << memapp
        file = self.search(memapp)
        if file
          found << file
        end
      end
      return [found, names.uniq]
    end

    # All files, including emeritus
    def self.files
      refresh
      @@files
    end

    private

    def self.refresh
      if File.mtime(@@MEMAPPS) != @@mtime
        @@files = Dir[File.join(@@MEMAPPS, '*')].map { |p|
          File.basename(p)
        }
        @@mtime = File.mtime(@@MEMAPPS)
      end
    end
  end
end

# for test purposes
if __FILE__ == $0
  puts ASF::MemApps.files.length
  puts ASF::MemApps.names.length
  puts ASF::MemApps.stems.length
  puts ASF::MemApps.emeritus.length
end
