#
# Fetch, retain, and query the list of reporter drafts
#

class Reporter
  Vue.util.defineReactive @@forgotten, nil

  # if digest has changed (or nothing was previously fetched) get list
  # of forgotten reports from the server
  def self.fetch(agenda, digest)
    if not @@forgotten or @@forgotten.digest != digest
      @@forgotten ||= {}
      if not agenda or agenda == Agenda.file
        JSONStorage.fetch 'reporter' do |forgotten|
          Chat.reporter_change(@@forgotten, forgotten)
          @@forgotten = forgotten
        end
      end
    end
  end

  # Find the item in the forgotten drafts list.  If list has not yet
  # been fetched, download the list.
  def self.find(item)
    if @@forgotten != nil
      return false if @@forgotten.agenda != Agenda.file
      return false unless item.attach =~ /^[A-Z]+$/ and item.stats

      draft = @@forgotten.drafts[item.attach]
      if draft and draft.project == item.stats.split('?')[1]
        return draft
      end
    else
      self.fetch()
    end
  end
end

Events.subscribe :reporter do |message|
  Reporter.fetch(message.agenda, message.digest) if message.digest
end
