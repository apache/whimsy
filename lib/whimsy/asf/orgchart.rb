##
# Part of the whimsy/ASF module of classes that provide simple access to ASF data.
module ASF
  
  ##
  # Reads and provides access to the officers/personnel-duties/ROLENAME.yaml files.
  class OrgChart
    @@duties = {}
    @@desc = {}
    
    def self.load
      @@source ||= ASF::SVN['private/foundation/officers/personnel-duties']
      @@source.untaint
      Dir["#{@@source}/*.txt"].each do |file|
        file.untaint # Since it's our own svn repo, trust it
        name = file[/.*\/(.*?)\.txt/, 1]
        next if @@duties[name] and @@duties[name]['mtime'] > File.mtime(file).to_f
        data = Hash[*File.read(file).split(/^\[(.*)\]\n/)[1..-1].map(&:strip)]
        next unless data['info']
        data['info'] = YAML.load(data['info'])
        data['mtime'] = File.mtime(file).to_f
        @@duties[name] = data
      end
      
      file = "#{@@source}/README".untaint
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
    # Access descriptions of the ['info'] section fields
    def self.desc
      self.load
      @@desc
    end
  end
end
