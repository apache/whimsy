#!/usr/bin/ruby

# The Agenda "service" maintains an agenda as an array of hash objects.
# Care is taken to never replace arrays, but rather to empty and refill
# existing arrays so that Angular.js's two way bindings will cause views
# to be updated.

module Angular::AsfBoardServices
  class JIRA
    @@fetched = false
    @@projects = []
    def self.exist(name)
      if not @@fetched
        @@fetched = true
        $http.get('json/jira').success {|result| @@projects.replace! result}
      end

      return @@projects.include? name
    end
  end

  class Agenda
    @@index = []

    # (re)-fetch agenda from server
    def self.refresh
      @@agenda ||= []

      $http.get("json/#{Data.get('agenda')}").success do |result|
        Agenda.put(result)
      end
    end

    # (re)-fetch agenda from server
    def self.put(agenda)
      # add forward and back links to entries in the agenda
      prev = nil
      agenda.forEach do |item|
        item.href = "##{item.title}"
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

      # rerun callbacks on each agenda item
      Agenda.forEach(@@callback) if @@callback
    end

    # retrieve agenda (fetching if necessary)
    def self.get()
      self.refresh() unless @@agenda
      return @@agenda
    end

    # run block on each item in the agenda; save block to be rerun when
    # agenda is refreshed
    def self.forEach(&block)
      @@callback = block
      self.get().forEach do |item|
        block item
      end
    end

    # return back a list of index entries
    def self.index
      return @@index
    end
  end

  class Pending
    @@fetched = false
    @@list = {comments: [], approved: []}

    def self.get
      $http.get("json/pending").success do |result|
        Pending.put result
      end

      return @@list
    end

    def self.comments
      self.get() unless @@fetched
      @@fetched = true
      return @@list.comments
    end

    def self.approved
      self.get() unless @@fetched
      @@fetched = true
      return @@list.approved
    end

    def self.put(value)
      @@list.approved.replace! value.approved

      for i in @@list.comments
        delete @@list.comments[i] unless value.comments[i]
      end

      for i in value.comments
        @@list.comments[i] = value.comments[i]
      end
    end
  end

  class Data
    def self.get(name)
      main = document.querySelector("main[data-#{name}]")
      return main && main.attributes["data-#{name}"].value
    end
  end
end
