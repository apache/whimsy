class Agenda
  @@index = []

  def self.load(list)
    @@index.clear()
    list.each do |item|
      @@index << Agenda.new(item)
    end
    return @@index
  end

  def initialize(entry)
    for name in entry
      self["_#{name}"] = entry[name]
    end
  end

  attr_accessor :attach, :title, :owner, :shepherd

  def href
    @title.gsub(/[^a-zA-Z0-9]+/, '-')
  end

  def color
    if not @title
      'blank'
    elsif @warnings
      'missing'
    elsif @missing
      'missing'
    elsif @approved
      if @approved.length < 5
        'ready'
      elsif @comments
        'commented'
      else
        'reviewed'
      end
    elsif @text or @report
      'available'
    elsif @text === undefined
      'missing'
    else
      'reviewed'
    end
  end
end
