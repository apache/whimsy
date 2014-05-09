#!/usr/bin/ruby

module Angular::AsfBoardServices

  # The Agenda "service" maintains an agenda as an array of hash objects.
  # Care is taken to never replace arrays, but rather to empty and refill
  # existing arrays so that Angular.js's two way bindings will cause views
  # to be updated.  A separate 'update' property is maintained to facilitate
  # watches for major updates.

  class Agenda
    @@index = []

    # (re)-fetch agenda from server
    def self.refresh()
      @@agenda ||= []
      @@agenda.update ||= 0
      $http.get("../#{Data.date}.json").success do |result, status|
        Agenda.put(result) unless status==304 and @@index.length>0
      end
    end

    # Replace the agenda, relinking and reindexing as we go.
    def self.put(agenda)
      # add forward and back links to entries in the agenda
      prev = nil
      agenda.each do |item|
        item.href = item.title.gsub(/[^a-zA-Z0-9]+/, '-')
        prev.next = item if prev
        item.prev = prev
        prev = item

        # link to test version of roster
        item.roster.sub! 'org/roster', 'org/test/roster' if item.roster
      end

      # remove president attachments from the normal flow
      agenda.each do |pres|
        match = pres.report and pres.report.
          match(/Additionally, please see Attachments (\d) through (\d)/)
        next unless match

        first = last = nil
        agenda.each do |item|
          first = item if item.attach == match[1]
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

      # add index entries to @@index, extract start and stop times
      @@index.clear()
      agenda.each do |item|
        @@index << item if item.index
        @@start = item.timestamp if item.title == 'Call to order'
        @@stop  = item.timestamp if item.title == 'Adjournment'
      end

      @@agenda.replace agenda

      @@agenda.update += 1
    end

    # retrieve agenda (fetching if necessary)
    def self.get()
      self.refresh() unless @@agenda

      unless @@update or Date.new().getTime() > Agenda.stop
        @@update = interval 10_000 do
          Agenda.refresh()
        end
      end

      return @@agenda
    end

    # return back a list of index entries
    def self.index
      return @@index
    end

    def self.ready()
      result = []
      initials = Data.get('initials')
      qprev = nil
      @@agenda.each do |item|
        next unless item.approved
        next if item.approved.include? initials
        next unless item.report or item.text

        result << item
        item.qhref = "queue/#{item.href}"

        item.qprev = qprev
        qprev.qnext = item if qprev
        qprev = item
      end
      qprev.qnext = nil if qprev
      return result
    end

    def self.start
      @@start
    end

    def self.stop
      @@stop
    end

    def self.find(title)
      return unless @@agenda
      match = nil
      @@agenda.each do |item|
        match = item if item.title == title
      end
      return match
    end
  end

  class Pending
    @@list = {comments: {}, approved: [], seen: {}, update: 0}

    def self.refresh()
      $http.get("../json/pending").success do |result|
        Pending.put result
      end

      @@fetched = true
      return @@list
    end

    def self.get()
      self.refresh() unless @@fetched
      return @@list
    end

    def self.put(value)
      angular.copy value.approved, @@list.approved if value.approved
      angular.copy value.comments, @@list.comments if value.comments
      angular.copy value.seen, @@list.seen         if value.seen
      @@list.update += 1
    end

    def self.count
      @@list.comments.keys().length + @@list.approved.keys().length
    end

    def self.approved
      self.refresh() unless @@fetched
      @@list.approved
    end
  end

  class Minutes
    @@index = {}
    @@draft = {}
    @@update = nil
    @@ready = 0
    @@posted = Data.get('drafts').split(' ')

    def self.get()
      if @@date != Data.date
        @@fetched = false
        $interval.cancel(@@update) if @@update
      end

      unless @@fetched and (Date.new().getTime()-@@fetched) < 10_000
        @@fetched = Date.new().getTime()
        @@date = Data.date

        $http.get("../json/minutes/#{@@date}").success do |result, status|
          if status != 304 or @@index.keys().length == 0
            angular.copy result, @@index
          end
          @@ready = true
        end
      end

      unless @@update or @@fetched<Agenda.start or @@fetched>Agenda.stop
        @@update = interval 10_000 do
          Minutes.get()
        end
      end

      return @@index
    end

    def self.put(minutes)
      angular.copy minutes, @@index
    end

    def self.new_actions
      Minutes.get()
      @@actions ||= []
      actions = []
      for title in @@index
        minutes = @@index[title] + "\n\n"
        pattern = RegExp.new('^(?:@|AI\s+)(\w+):?\s+([\s\S]*?)\n\n', 'g')
        match = pattern.exec(minutes)
        while match
          text = match[2].gsub(/\n/, ' ')
          indent = match[1].gsub(/./, ' ') + '    '
          item = Agenda.find(title)
          actions << self.find_action(title, (item.href if item),
            Flow.comment(text, "* #{match[1]}", indent));
          match = pattern.exec(minutes)
        end
      end
      @@actions.replace(actions)
      @@actions
    end

    def self.find_action(title, link, text)
      match = @@actions.find do |action|
        action.title == title and action.link == link and action.text == text
      end
      return match || {title: title, link: link, text: text}
    end

    def self.ready
      @@ready
    end

    def self.complete
      @@index['Adjournment'] ? 1 : 0
    end

    def self.draft
      @@draft
    end

    def self.posted
      @@posted
    end

    def self.status
      Minutes.ready + Minutes.complete + Minutes.posted.length
    end
  end

  class JIRA
    @@fetched = false
    @@projects = []
    def self.exist(name)
      if not @@fetched
        @@fetched = true
        ~'#clock'.show
        $http.get('../json/jira').success do |result|
          @@projects.replace result
          ~'#clock'.hide
        end
      end

      return @@projects.include? name
    end
  end

  class Data
    def self.get(name)
      main = document.querySelector("main[data-#{name}]")
      return main && main.attributes["data-#{name}"].value
    end

    def self.date
      Data.get('agenda')[/(\d+_\d+_\d+)/,1].gsub('_', '-')
    end

    def self.drafts
      Data.get('drafts').split(' ')
    end
  end


  class Flow
    # reflow comment
    def self.comment(comment, initials, indent='    ')
      lines = comment.split("\n")
      len = 71 - indent.length
      for i in 0...lines.length
        lines[i] = (i == 0 ? initials + ': ' : "#{indent} ") + lines[i].
          gsub(/(.{1,#{len}})( +|$\n?)|(.{1,#{len}})/, "$1$3\n#{indent}").
          trim()
      end
      return lines.join("\n")
    end

    # reflow text
    def self.text(text)
      # join consecutive lines (making exception for <markers> like <private>)
      text.gsub! /([^\s>])\n(\w)/, '$1 $2'

      # reflow each line
      lines = text.split("\n")
      for i in 0...lines.length
        indent = lines[i].match(/( *)(.?.?)(.*)/m)

        if indent[1] == '' or indent[3] == ''
          # not indented (or short) -> split
          lines[i] = lines[i].
            gsub(/(.{1,78})( +|$\n?)|(.{1,78})/, "$1$3\n").
            sub(/[\n\r]+$/, '')
        else
          # preserve indentation.  indent[2] is the 'bullet' (if any) and is
          # only to be placed on the first line.
          n = 76 - indent[1].length;
          lines[i] = indent[3].
            gsub(/(.{1,#{n}})( +|$\n?)|(.{1,#{n}})/, indent[1] + "  $1$3\n").
            sub(indent[1] + '  ', indent[1] + indent[2]).
            sub(/[\n\r]+$/, '')
        end
      end

      return lines.join("\n")
    end
  end

  class Actions
    @@buttons = []
    @@forms = []

    def self.reset()
      @@buttons.clear()
      @@forms.clear()
    end

    def self.buttons
      @@buttons
    end

    def self.forms
      @@forms
    end

    def self.add button, form
      @@buttons << button unless @@buttons.include? button
      @@forms << form if form and not @@forms.include? form
    end

    def self.remove button
      index = @@buttons.indexOf(button)
      @@buttons.splice(index, 1) if index > -1
    end
  end
end
