class Pending
  def self.update_file
    user = ENV['REMOTE_USER']
    "#{MINUTES_WORK}/#{$USER}.yml".untaint if $USER =~ /\A\w+\Z/
  end

  def self.get
    if File.exist? update_file
      YAML.load_file(update_file)
    else
      {'approved' => [], 'comments' => {}}
    end
  end

  def self.put(update)
    File.open(update_file, 'w') do |file|
      file.write YAML.dump(update)
    end
  end
end
