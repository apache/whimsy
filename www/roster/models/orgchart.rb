class OrgChart
  @@duties = {}
  @@desc = {}

  def self.load
    @@source ||= ASF::SVN['personnel-duties']

    Dir[File.join(@@source, '*.txt')].each do |file|
      name = file[/.*\/(.*?)\.txt/, 1]
      next if @@duties[name] and @@duties[name]['mtime'] > File.mtime(file).to_f
      data = Hash[*File.read(file).split(/^\[(.*)\]\n/)[1..-1].map(&:strip)]
      next unless data['info']
      data['info'] = YAML.load(data['info'])
      data['mtime'] = File.mtime(file).to_f
      @@duties[name] = data
    end

    file = File.join(@@source, 'README')
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

  def self.[](name)
    self.load
    @@duties[name]
  end
  
  def self.desc
    self.load
    @@desc
  end
end