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
