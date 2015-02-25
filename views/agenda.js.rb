class Agenda
  @@index = []

  def self.load(list)
    @@index.clear()
    prev = nil
    list.each do |item|
      item = Agenda.new(item)
      item.prev = prev
      prev.next = item if prev
      prev = item
      @@index << item
    end
    return @@index
  end

  def self.index
    @@index
  end

  def self.find(path)
    result = nil
    @@index.each do |item|
      result = item if item.href == path
    end
    return result
  end

  def initialize(entry)
    for name in entry
      self["_#{name}"] = entry[name]
    end
  end

  attr_reader :attach, :title, :owner, :shepherd, :index

  def href
    @title.gsub(/[^a-zA-Z0-9]+/, '-')
  end

  def text
    @text || @report
  end

  def self.view
    Index
  end

  def self.color
    'blank'
  end

  def self.title
    @@date
  end

  def self.prev
    result = {title: 'Help', href: 'help'}

    @@agendas.each do |agenda|
      date = agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')

      if date < @@date and (result.title == 'Help' or date > result.title)
	result = {title: date, href: "../#{date}/"}
      end
    end

    result
  end

  def self.next
    result = {title: 'Help', href: 'help'}

    @@agendas.each do |agenda|
      date = agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')

      if date > @@date and (result.title == 'Help' or date < result.title)
	result = {title: date, href: "../#{date}/"}
      end
    end

    result
  end

  def view
    Report
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
