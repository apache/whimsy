class Pending
  def self.update_file(user)
    "#{MINUTES_WORK}/#{user}.yml".untaint if user =~ /\A\w+\Z/
  end

  def self.get(user)
    file = update_file(user)
    if File.exist? file
      YAML.load_file(file)
    else
      {'approved' => [], 'comments' => {}}
    end
  end

  def self.put(user, update)
    File.open(update_file(user), 'w') do |file|
      file.write YAML.dump(update)
    end
  end
end
