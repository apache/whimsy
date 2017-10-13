class Pending
  # determine the name of the work file associated with a given user
  def self.work_file(user)
    "#{AGENDA_WORK}/#{user}.yml".untaint if user =~ /\A\w+\z/
  end

  # fetch and parse a work file
  def self.get(user, agenda=nil)

    file = work_file(user)
    response = ((file and File.exist?(file)) ? YAML.load_file(file) : {})

    # reset pending when agenda changes
    if agenda and agenda > response['agenda'].to_s
      response = {'agenda' => agenda}
    end

    # provide empty defaults
    response['approved'] ||= []
    response['unapproved'] ||= []
    response['flagged'] ||= []
    response['unflagged'] ||= []
    response['comments'] ||= {} 
    response['seen']     ||= {}

    response
  end

  # update a work file
  def self.update(user, agenda=nil)
    pending = self.get(user, agenda)

    yield pending

    work = work_file(user)
    File.open(work, 'w') do |file|
      file.write YAML.dump(pending)
    end

    pending
  end
end
