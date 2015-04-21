#
# This is the client model for an entire Agenda.  Class methods refer to
# the agenda as a whole.  Instance methods refer to an individual agenda
# item.
#

class Agenda
  @@index = []

  # (re)-load an agenda, creating instances for each item, and linking
  # each instance to their next and previous items.
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

    # remove president attachments from the normal flow
    @@index.each do |pres|
      match = (pres.title == 'President') and pres.text and pres.text.
        match(/Additionally, please see Attachments (\d) through (\d)/)
      next unless match

      first = last = nil
      @@index.each do |item|
        first = item if item.attach == match[1]
        item._shepherd ||= pres.shepherd if first and !last
        last  = item if item.attach == match[2]
      end

      if first and last
        first.prev.next = last.next
        last.next.prev = first.prev
        last.next.index = first.index
        first.index = nil
        last.next = pres
        first.prev = pres
      end
    end

    Main.refresh()
    return @@index
  end

  # return the entire agenda
  def self.index
    @@index
  end

  # find an agenda item by path name
  def self.find(path)
    result = nil
    @@index.each do |item|
      result = item if item.href == path
    end
    return result
  end

  # initialize an entry by copying each JSON property to a class instance
  # variable.
  def initialize(entry)
    for name in entry
      self["_#{name}"] = entry[name]
    end
  end

  # provide read-only access to a number of properties 
  attr_reader :attach, :title, :owner, :shepherd, :index, :timestamp, :digest
  attr_reader :approved, :roster, :prior_reports, :stats, :missing, :people
  attr_reader :chair_email, :mail_list, :warnings

  # compute href by taking the title and replacing all non alphanumeric
  # characters with dashes
  def href
    @title.gsub(/[^a-zA-Z0-9]+/, '-')
  end

  # return the text or report for the agenda item
  def text
    @text || @report
  end

  # return comments as an array of individual comments
  def comments
    results = []
    return results unless @comments

    comment = ''
    @comments.split("\n").each do |line|
      if line =~ /^\S/
        results << comment unless comment.empty?
        comment = line
      else
        comment += "\n" + line
      end
    end

    results << comment unless comment.empty?
    return results
  end

  # item's comments excluding comments that have been seen before
  def unseen_comments
    visible = []
    seen = Pending.seen[@attach] || []
    self.comments.each do |comment|
      visible << comment unless seen.include? comment
    end
    return visible
  end

  # retrieve the pending comment (if any) associated with this agenda item
  def pending
    Pending.comments[@attach]
  end

  # retrieve the action items associated with this agenda item
  def actions
    if @title == 'Action Items'
      @actions
    else
      item = Agenda.find('Action-Items')
      item ? item.actions[@title] : []
    end
  end

  def ready_for_review(initials)
    return defined? @approved and not @missing and
      not @approved.include? initials and
      not Pending.rejected.include? @attach
  end

  # the default view to use for the agenda as a whole
  def self.view
    Index
  end

  # buttons to show on the index page
  def self.buttons
    [{button: Refresh}, {form: Post, text: 'add resolution'}]
  end

  # the default banner color to use for the agenda as a whole
  def self.color
    'blank'
  end

  # allow the date property to be changed
  def self.date=(date)
    @@date=date
  end

  # the default title for the agenda as a whole
  def self.title
    @@date
  end

  # the file associated with this agenda
  def self.file
    "board_agenda_#{@@date.gsub('-', '_')}.txt"
  end

  # previous link for the agenda index page
  def self.prev
    result = {title: 'Help', href: 'help'}

    Server.agendas.each do |agenda|
      date = agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')

      if date < @@date and (result.title == 'Help' or date > result.title)
        result = {title: date, href: "../#{date}/"}
      end
    end

    result
  end

  # next link for the agenda index page
  def self.next
    result = {title: 'Help', href: 'help'}

    Server.agendas.each do |agenda|
      date = agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')

      if date > @@date and (result.title == 'Help' or date < result.title)
	      result = {title: date, href: "../#{date}/"}
      end
    end

    result
  end

  # default view for an individual agenda item
  def view
    if @title == 'Action Items'
      ActionItems
    else
      Report
    end
  end

  # buttons and forms to show with this report
  def buttons
    list = []

    unless @comments === undefined # some reports don't have comments
      if self.pending
        list << {form: AddComment, text: 'edit comment'}
      else
        list << {form: AddComment, text: 'add comment'}
      end

      if self.approved and not self.approved.include? Server.initials
        list << {button: Approve} unless self.missing
      end
    end

    list << {button: Attend} if @title == 'Roll Call'

    if @attach =~ /^(\d|7?[A-Z]+|4[A-Z])$/
      if @missing
        list << {form: Post, text: 'post report'} 
      elsif @attach =~ /^7\w/
        list << {form: Post, text: 'edit resolution'} 
      else
        list << {form: Post, text: 'edit report'} 
      end
    end

    list
  end

  # banner color for this agenda item
  def color
    if not @title
      'blank'
    elsif @warnings
      'missing'
    elsif @missing
      'missing'
    elsif Pending.rejected.include? @attach
      'rejected'
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
