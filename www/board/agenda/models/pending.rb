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
    @@seen[work] = File.mtime(work)

    IPC.post type: :pending, value: pending, private: user

    pending
  end

  # listen for changes to pending and minutes files
  @@listener = Listen.to(AGENDA_WORK) do |modified, added, removed|
    modified.each do |path|
      next if path.end_with? '/sessions/present.yml'
      next if File.exist?(path) and @@seen[path] == File.mtime(path)
      file = File.basename(path)
      if file =~ /^board_minutes_\d{4}_\d\d_\d\d\.yml$/
        agenda = file.sub('minutes', 'agenda').sub('.yml', '.txt')
        IPC.post type: :minutes, agenda: agenda, value: YAML.load_file(path)
      elsif file =~ /^(\w+)\.yml$/
        IPC.post type: :pending, private: $1, value: YAML.load_file(path)
      else
        STDERR.puts file
      end
    end
  end

  # disable listening when running tests
  @@listener = Struct.new(:start, :stop).new if ENV['RACK_ENV'] == 'test'

  @@seen = {}

  @@listener.start
end
