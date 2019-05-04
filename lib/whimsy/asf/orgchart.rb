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

##
# Part of the whimsy/ASF module of classes that provide simple access to ASF
# data.
module ASF # :nodoc:
  
  ##
  # Reads and provides access to the
  # <tt>officers/personnel-duties/ROLENAME.yaml</tt> files.
  class OrgChart
    @@duties = {}
    @@desc = {}
    
    # parse any changed YAML role files.
    def self.load
      @@source ||= ASF::SVN['personnel-duties']
      @@source.untaint
      Dir[File.join(@@source, '*.txt')].each do |file|
        file.untaint # Since it's our own svn repo, trust it
        name = file[/.*\/(.*?)\.txt/, 1]
        next if @@duties[name] and @@duties[name]['mtime'] > File.mtime(file).to_f
        data = Hash[*File.read(file).split(/^\[(.*)\]\n/)[1..-1].map(&:strip)]
        next unless data['info']
        data['info'] = YAML.load(data['info'])
        data['mtime'] = File.mtime(file).to_f
        @@duties[name] = data
      end
      
      file = File.join(@@source, 'README').untaint
      unless @@desc['mtime'] and @@desc['mtime'] > File.mtime(file).to_f
        data = Hash[*File.read(file).split(/^\[(.*)\]\n/)[1..-1].map(&:strip)]
        if data['info'] then
          data = YAML.load(data['info'])
          data['mtime'] = File.mtime(file).to_f
          @@desc = data
        end
      end
      
      @@duties
    end
    
    ##
    # Access data from a specific role
    # :yield: Hash with ['info'] -> hash of info fields; plus any other [sections]
    def self.[](name)
      self.load
      @@duties[name]
    end
    
    ##
    # Access descriptions of the <tt>['info']</tt> section fields
    def self.desc
      self.load
      @@desc
    end
  end
end
