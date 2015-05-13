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

  def self.actions
    actions = []

    for title in @@list
      minutes = @@list[title] + "\n\n"
      pattern = RegExp.new('^(?:@|AI\s+)(\w+):?\s+([\s\S]*?)(\n\n|$)', 'gm')
      match = pattern.exec(minutes)
      while match
        actions << {owner: match[1], text: match[2], item: Agenda.find(title)}
        match = pattern.exec(minutes)
      end
    end

    return actions
  end

  # fetch minutes for a given agenda item, by title
  def self.get(title)
    return @@list[title]
  end
end

Events.subscribe :minutes do |message|
  Minutes.load(message.data) if message.file == Agenda.file
end
