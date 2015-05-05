class Pending
  # determine the name of the work file associated with a given user
  def self.work_file(user)
    "#{AGENDA_WORK}/#{user}.yml".untaint if user =~ /\A\w+\Z/
  end

  # fetch and parse a work file
  def self.get(user, agenda=nil)
    file = work_file(user)
    response = (File.exist?(file) ? YAML.load_file(file) : {})

    # reset pending when agenda changes
    if agenda and agenda > response['agenda'].to_s
      response = {'agenda' => agenda}
    end

    # provide empty defaults
    response['approved'] ||= []
    response['rejected'] ||= []
    response['comments'] ||= {} 
    response['seen']     ||= {}

    response
  end

  # update a work file
  def self.update(user, agenda=nil)
    pending = self.get(user, agenda)

    yield pending

    File.open(work_file(user), 'w') do |file|
      file.write YAML.dump(pending)
    end

    Events.post type: :pending, value: pending, private: user

    pending
  end
end
