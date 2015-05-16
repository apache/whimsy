class Pending
  def self.update_file(user)
    "#{MINUTES_WORK}/#{user}.yml".untaint if user =~ /\A\w+\Z/
  end

  def self.get(user)
    file = update_file(user)
    response = (File.exist?(file) ? YAML.load_file(file) : {})

    # provide empty defaults
    response['approved'] ||= []
    response['rejected'] ||= []
    response['comments'] ||= {} 
    response['seen']     ||= {}

    response
  end

  def self.put(user, update)
    File.open(update_file(user), 'w') do |file|
      file.write YAML.dump(update)
    end
  end
end
