class OrgChart
  @@duties = {}

  def self.load
    @@source ||= ASF::SVN['private/foundation/officers/personnel-duties']

    Dir["#{@@source}/*.txt"].each do |file|
      name = file[/.*\/(.*?)\.txt/, 1]
      next if @@duties[name] and @@duties[name]['mtime'] > File.mtime(file).to_f
      data = Hash[*File.read(file).split(/^\[(.*)\]\n/)[1..-1].map(&:strip)]
      next unless data['info']
      data['info'] = YAML.load(data['info'])
      data['mtime'] = File.mtime(file).to_f
      @@duties[name] = data
    end

    @@duties
  end

  def self.[](name)
    self.load
    @@duties[name]
  end
end
