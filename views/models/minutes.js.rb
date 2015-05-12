#
# This is the client model for draft Minutes.
#

class Minutes
  @@list = {}

  # (re)-load minutes
  def self.load(list)
    @@list = {}

    if list
      for title in list
        @@list[title] = list[title]
      end
    end
  end

  # fetch minutes for a given agenda item, by title
  def self.get(title)
    return @@list[title]
  end
end

Events.subscribe :minutes do |message|
  Minutes.load(message.data) if message.file == Agenda.file
end
