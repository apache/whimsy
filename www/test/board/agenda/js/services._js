#!/usr/bin/ruby

# The Agenda "service" maintains an agenda as an array of hash objects.
# Care is taken to never replace arrays, but rather to empty and refill
# existing arrays so that Angular.js's two way bindings will cause views
# to be updated.

module Angular::AsfBoardServices
  class Agenda
    @@index = []

    # (re)-fetch agenda from server
    def self.refresh
      @@agenda ||= []

      $http.get("json/#{self.filename()}").success do |result|
        @@index.length = 0

        # add forward and back links to entries in the agenda
        prev = nil
        result.forEach do |item|
          item.href = "##{item.title}"
          prev.next = item if prev
          item.prev = prev
          prev = item
        end

        # remove president attachments from the normal flow
        result.forEach do |pres|
          match = pres.report and pres.report.
            match(/Additionally, please see Attachments (\d) through (\d)/)
          next unless match

          first = last = nil
          result.forEach do |item|
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
        result.forEach do |item|
          @@index.push item if item.index
        end

        @@agenda.length == 0
        @@agenda.push(*result)

        # rerun callbacks on each agenda item
        Agenda.forEach(@@callback) if @@callback
      end
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

    # retrieve file name associated with the agenda from the document itself
    def self.filename
      return document.querySelector('div[data-agenda]').
        attributes['data-agenda'].value
    end
  end

  class Pending
    @@list = {comments: [], approved: []}

    def self.get
      return @@list
    end

    def self.comments
      return @@list.comments
    end

    def self.approved
      return @@list.approved
    end

    def self.put(value)
      @@list.comments = value.comments
      @@list.approved = value.approved
    end
  end
end
