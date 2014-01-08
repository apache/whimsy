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
    def self.refresh
      @@agenda ||= []
      @@agenda.update ||= 0
      $http.get("json/#{Data.get('agenda')}").success do |result|
        Agenda.put(result)
      end
    end

    # Replace the agenda, relinking and reindexing as we go.
    def self.put(agenda)
      # add forward and back links to entries in the agenda
      prev = nil
      agenda.forEach do |item|
        item.href = "#/#{item.title}"
        prev.next = item if prev
        item.prev = prev
        prev = item
      end

      # remove president attachments from the normal flow
      agenda.forEach do |pres|
        match = pres.report and pres.report.
          match(/Additionally, please see Attachments (\d) through (\d)/)
        next unless match

        first = last = nil
        agenda.forEach do |item|
          first = item if item.attach == match[1]
          last  = item if item.attach == match[2]
        end

        if first and last
          first.prev.next = last.next
          last.next.prev = first.prev
          last.next.prev = first.prev
          first.prev = pres
          last.next.index = first.index
          first.index = nil
        end
      end

      # add index entries to @@index
      @@index.clear!
      agenda.forEach do |item|
        @@index.push item if item.index
      end

      @@agenda.replace! agenda

      @@agenda.update += 1
    end

    # retrieve agenda (fetching if necessary)
    def self.get()
      self.refresh() unless @@agenda
      return @@agenda
    end

    # return back a list of index entries
    def self.index
      return @@index
    end

    def self.ready
      result = []
      pending = Pending.get()
      initials = Data.get('initials')
      qprev = nil
      @@agenda.forEach do |item|
        next unless item.approved
        next if pending.approved.include? item.attach
        next if item.approved.include? initials
        next unless item.report or item.text

        result.push item
        item.qhref = "#/queue/#{item.title}"

        item.qprev = qprev
        qprev.qnext = item if qprev
        qprev = item
      end
      qprev.qnext = nil if qprev
      return result
    end
  end

  class Pending
    @@list = {comments: {}, approved: [], update: 0}

    def self.refresh
      $http.get("json/pending").success do |result|
        Pending.put result
      end

      @@fetched = true
      return @@list
    end

    def self.get
      self.refresh() unless @@fetched
      return @@list
    end

    def self.comments
      self.refresh() unless @@fetched
      return @@list.comments
    end

    def self.approved
      self.refresh() unless @@fetched
      return @@list.approved
    end

    def self.put(value)
      @@list.approved.replace! value.approved

      for i in @@list.comments
        delete @@list.comments[i]
      end

      for i in value.comments
        @@list.comments[i] = value.comments[i]
      end

      @@list.update += 1
    end
  end

  class JIRA
    @@fetched = false
    @@projects = []
    def self.exist(name)
      if not @@fetched
        @@fetched = true
        ~'#clock'.show
        $http.get('json/jira').success do |result| 
          @@projects.replace! result
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
  end
end
