
# This is the client model for an entire Agenda.  Class methods refer to
# the agenda as a whole.  Instance methods refer to an individual agenda
# item.
#

class Agenda
  Vue.util.defineReactive @@index, []
  @@etag = nil
  @@digest = nil
  Vue.util.defineReactive @@date, ''
  Vue.util.defineReactive @@approved, '?'
  @@color = 'blank'

  # (re)-load an agenda, creating instances for each item, and linking
  # each instance to their next and previous items.
  def self.load(list, digest)
    return unless list
    before = @@index
    @@digest = digest
    @@index = []
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
      match = (pres.title == 'President' and pres.text and pres.text.
        match(/Additionally, please see Attachments (\d) through (\d)/))
      next unless match

      # find first and last president report; update shepherd along the way
      first = last = nil
      @@index.each do |item|
        first = item if item.attach == match[1]
        item._shepherd ||= pres.shepherd if first and !last
        last  = item if item.attach == match[2]
      end

      # remove president attachments from the normal flow
      if first and last and not Minutes.started
        first.prev.next = last.next
        last.next.prev = first.prev
        last.next.index = first.index
        first.index = nil
        last.next = pres
        first.prev = pres
      end
    end

    @@date = Date.new(@@index[0].timestamp).toISOString()[/(.*?)T/, 1]
    Main.refresh()
    Chat.agenda_change(before, @@index)
    return @@index
  end

  # fetch agenda if etag is not supplied
  def self.fetch(etag, digest)
    if etag
      @@etag = etag
    elsif digest != @@digest or not @@etag
      if PageCache.enabled
        loaded = false

        # if bootstrapping and cache is available, load it
        if not digest
          caches.open('board/agenda').then do |cache|
            cache.match("../#{@@date}.json").then do |response|
              if response
                response.json().then do |json|
                  Agenda.load(json) unless loaded
                  Main.refresh()
                end
              end
            end
          end
        end

        # set fetch options: credentials and etag
        options = {credentials: 'include'}
        options['headers'] = {'If-None-Match' => @@etag} if @@etag
        request = Request.new("../#{@@date}.json", options)

        # perform fetch
        fetch(request).then do |response|
          if response and response.ok
            loaded = true

            # load response into the agenda
            response.clone().json().then do |json|
              @@etag = response.headers.get('etag')
              Agenda.load(json)
              Main.refresh()
            end

            # save response in the cache
            caches.open('board/agenda').then do |cache|
              cache.put(request, response)
            end
          end
        end
      else
        # AJAX fallback
        xhr = XMLHttpRequest.new()
        xhr.open('GET', "../#{@@date}.json", true)
        xhr.setRequestHeader('If-None-Match', @@etag) if @@etag
        xhr.responseType = 'text'
        def xhr.onreadystatechange()
          if xhr.readyState==4 and xhr.status==200 and xhr.responseText!=''
            @@etag = xhr.getResponseHeader('ETag')
            Agenda.load(JSON.parse(xhr.responseText))
            Main.refresh()
          end
        end
        xhr.send()
      end
    end

    @@digest = digest
  end

  # return the entire agenda
  def self.index
    @@index
  end

  # find an agenda item by path name
  def self.find(path)
    result = nil
    path = path.gsub(/\W+/, '-')
    @@index.each do |item|
      result = item if item.href == path
    end
    return result
  end

  # initialize an entry by copying each JSON property to a class instance
  # variable.
  def initialize(entry)
    entry.each_pair do |name, value|
      self["_#{name}"] = value
    end
  end

  # provide read-only access to a number of properties
  attr_reader :attach, :title, :owner, :timestamp, :digest, :mtime
  attr_reader :approved, :roster, :prior_reports, :stats, :people, :notes
  attr_reader :chair_email, :mail_list, :warnings, :flagged_by

  # provide read/write access to other properties
  attr_accessor :index, :shepherd
  attr_writer :color

  def fulltitle
    @fulltitle || @title
  end

  # override missing if minutes aren't present
  def missing
    if @missing
      return true
    elsif @attach =~ /^3\w$/
      if Server.drafts.include? @text[/board_minutes_\w+.txt/]
        return false
      elsif Minutes.get(@title) == 'approved' or @title =~ /^Action/
        return false
      else
        return true
      end
    else
      return false
    end
  end

  # report was marked as NOT accepted during the meeting
  def rejected
    Minutes.rejected and Minutes.rejected.include?(@title)
  end

  # PMC has missed two consecutive months
  def nonresponsive
    @notes and @notes.include? 'missing' and
      @notes.sub(/^.*missing/, '').split(',').length >= 2
  end

  # extract (new) chair name from resolutions
  def chair_name
    if @chair
      @people[@chair].name
    end
  end

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
    splitComments(@comments)
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
    Pending.comments and Pending.comments[@attach]
  end

  # retrieve the action items associated with this agenda item
  def actions
    if @title == 'Action Items'
      @actions
    else
      item = Agenda.find('Action-Items')
      list = []
      if item
        item.actions.each {|action| list << action if action.pmc == @title}
      end
      list
    end
  end

  def special_orders
    items = []

    if @attach =~ /^[A-Z]+$/
      Agenda.index.each do |item|
        items << item if item.attach =~ /^7\w/ and item.roster == @roster
      end
    end

    return items
  end

  def ready_for_review(initials)
    return defined?(@approved) && !self.missing &&
      !@approved.include?(initials) &&
      !(@flagged_by && @flagged_by.include?(initials))
  end

  # determine if this agenda was approved in a later meeting
  def self.approved
    @@approved = 'approved' unless defined? fetch

    if @@approved == '?'
      options = {month: 'long', day: 'numeric', year: 'numeric'}
      date = Date.new(Agenda.file[/\d\d\d\d_\d\d_\d\d/].
        gsub('_', '-') + 'T18:30:00.000Z').toLocaleString('en-US', options)

      Server.agendas.each do |agenda|
        next if agenda <= Agenda.file
        url = "../#{agenda[/\d\d\d\d_\d\d_\d\d/].gsub('_', '-')}.json"
        fetch(url, credentials: 'include').then do |response|
          if response.ok
            response.json().then do |agenda|
              agenda.each do |item|
                @@approved = item.minutes if item.title == date and item.minutes
              end
            end
          end
        end
      end

      @@approved = 'tabled'
    end

    return @@approved
  end

  # the default view to use for the agenda as a whole
  def self.view
    Index
  end

  # buttons to show on the index page
  def self.buttons
    list = [{button: Refresh}]

    if not Minutes.complete
      list << {form: Post, text: 'add item'}
    elsif [:director, :secretary].include? User.role
      list << {form: Summary} unless Minutes.summary_sent
    end

    if User.role == :secretary
      if Agenda.approved == 'approved'
        list << {form: PublishMinutes}
      elsif Minutes.ready_to_post_draft
        list << {form: DraftMinutes}
      end
    end

    list
  end

  # the default banner color to use for the agenda as a whole
  def self.color
    @@color
  end

  def self.color=(color)
    @@color = color
  end

  # fetch the start date
  def self.date
    @@date
  end

  # is today the meeting day?
  def self.meeting_day
    Date.new().toISOString().slice(0,10) >= @@date
  end

  # the default title for the agenda as a whole
  def self.title
    @@date
  end

  # the file associated with this agenda
  def self.file
    "board_agenda_#{@@date.gsub('-', '_')}.txt"
  end

  # get the digest of the file associated with this agenda
  def self.digest
    @@digest
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

  # find the shortest match for shepherd name (example: Rich)
  def self.shepherd
    _shepherd = nil

    firstname = User.firstname.downcase()
    Agenda.index.each do |item|
      if
        item.shepherd and
        firstname.start_with? item.shepherd.downcase() and
        (not _shepherd or item.shepherd.length < _shepherd.length)
      then
        _shepherd = item.shepherd
      end
    end

    return _shepherd
  end

  # summary
  def self.summary
    results = []

    # committee reports
    count = 0
    link = nil
    Agenda.index.each do |item|
      if item.attach =~ /^[A-Z]+$/
        count += 1
        link ||= item.href
      end
    end
    results << {color: 'available', count: count, href: link,
        text: 'committee reports'}

    # special orders
    count = 0
    link = nil
    Agenda.index.each do |item|
      if item.attach =~ /^7[A-Z]+$/
        count += 1
        link ||= item.href
      end
    end
    results << {color: 'available', count: count, href: link,
      text: 'special orders'}

    # discussion items
    count = 0
    link = nil
    Agenda.index.each do |item|
      if item.attach =~ /^8[.A-Z]+$/
        count += 1 unless item.attach == '8.' and not item.text
        link ||= item.href
      end
    end
    results << {color: 'available', count: count, href: link,
      text: 'discussion items'}

    # awaiting preapprovals
    count = 0
    Agenda.index.each do |item|
      count += 1 if item.color == 'ready' and item.title != 'Action Items'
    end
    results << {color: 'ready', count: count, href: 'queue',
      text: 'awaiting preapprovals'}

    # flagged reports
    count = 0
    Agenda.index.each {|item| count += 1 if item.flagged_by}
    results << {color: 'commented', count: count, href: 'flagged',
      text: 'flagged reports'}

    # missing reports
    count = 0
    Agenda.index.each {|item| count += 1 if item.missing}
    results <<  {color: 'missing', count: count, href: 'missing',
      text: 'missing reports'}

    # rejected reports
    count = 0
    Agenda.index.each {|item| count += 1 if item.rejected}
    if Minutes.started or count > 0
      results <<  {color: 'missing', count: count, href: 'rejected',
        text: 'not accepted'}
    end

    return results
  end

  #
  # Methods on individual agenda items
  #

  # default view for an individual agenda item
  def view
    if @title == 'Action Items'
      if @text or Minutes.started
        ActionItems
      else
        SelectActions
      end
    elsif @title == 'Roll Call' and User.role == :secretary
      RollCall
    elsif @title == 'Adjournment' and User.role == :secretary
      Adjournment
    else
      Report
    end
  end

  # buttons and forms to show with this report
  def buttons
    list = []

    unless (@attach !~ /^\d+$/ and @comments === undefined) or Minutes.complete
      # some reports don't have comments
      if self.pending
        list << {form: AddComment, text: 'edit comment'}
      else
        list << {form: AddComment, text: 'add comment'}
      end
    end

    list << {button: Attend} if @title == 'Roll Call'

    if @attach =~ /^(\d+|7?[A-Z]+|4[A-Z]|8[.A-Z])$/
      if User.role == :secretary or not Minutes.complete
        unless Minutes.draft_posted
          if @attach =~ /^8[.A-Z]/
            if @attach =~ /^8[A-Z]/
              list << {form: Post, text: 'edit item'}
            elsif not text or @text.strip().empty?
              list << {form: Post, text: 'post item'}
            else
              list << {form: Post, text: 'edit items'}
            end
          elsif self.missing
            list << {form: Post, text: 'post report'}
          elsif @attach =~ /^7\w/
            list << {form: Post, text: 'edit resolution'}
          else
            list << {form: Post, text: 'edit report'}
          end
        end
      end
    end

    if User.role == :director
      unless self.missing or @comments === undefined or Minutes.complete
        list << {button: Approve} if @attach =~ /^(3[A-Z]|\d+|[A-Z]+)$/
      end

    elsif User.role == :secretary
      unless Minutes.draft_posted
        if @attach =~ /^7\w/
          list << {form: Vote}
        elsif Minutes.get(@title)
          list << {form: AddMinutes, text: 'edit minutes'}
        elsif ['Call to order', 'Adjournment'].include? @title
          list << {button: Timestamp}
        else
          list << {form: AddMinutes, text: 'add minutes'}
        end
      end

      if @attach =~ /^3\w/
        if
          Minutes.get(@title) == 'approved' and
          Server.drafts.include? @text[/board_minutes_\w+\.txt/]
        then
          list << {form: PublishMinutes}
        end
      elsif @title == 'Adjournment'
        if Minutes.ready_to_post_draft
          list << {form: DraftMinutes}
        end
      end
    end

    list
  end

  # determine if this item is flagged, accounting for pending actions
  def flagged
    return true if Pending.flagged and Pending.flagged.include? @attach
    return false unless @flagged_by
    return false if @flagged_by.length == 1 and
      @flagged_by.first == User.initials and
      Pending.unflagged.include?(@attach)
    return ! @flagged_by.empty?
  end

  # determine if this report can be skipped during the course of the meeting
  def skippable
    return false if self.flagged

    if self.missing and Agenda.meeting_day
      return true if @to == 'president'
      return true unless @notes or Server.userid == 'test'
      return false
    end

    return false if @approved and @approved.length < 5 and Agenda.meeting_day
    return true
  end

  # banner color for this agenda item
  def color
    if self.flagged
      'commented'
    elsif @color
      @color
    elsif not @title
      'blank'
    elsif @warnings
      'missing'
    elsif self.missing or self.rejected
      'missing'
    elsif @approved
      if @approved.length < 5
        'ready'
      else
        'reviewed'
      end
    elsif self.title == 'Action Items'
      if self.actions.empty?
        'missing'
      elsif self.actions.any? {|action| action.status.empty?}
        'ready'
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

  # who to copy on emails
  def cc
    if @to == 'president'
      'operations@apache.org'
    else
      'board@apache.org'
    end
  end
end

Events.subscribe :agenda do |message|
  Agenda.fetch(nil, message.digest) if message.file == Agenda.file
end

Events.subscribe :server do |message|
  Server.drafts  = message.drafts  if message.drafts
  Server.agendas = message.agendas if message.agendas
end
