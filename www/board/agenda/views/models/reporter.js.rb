#
# Fetch, retain, and query the list of reporter drafts
#

class Reporter
  Vue.util.defineReactive @@forgotten, nil

  def self.load(value)
    @@forgotten = value
  end

  def self.find(item)
    if @@forgotten != nil
      return false if @@forgotten.agenda != Agenda.file
      return false unless item.attach =~ /^[A-Z]+$/ and item.stats

      draft = @@forgotten.drafts[item.attach]
      if draft and draft.project == item.stats.split('?')[1]
        return draft
      end
    else
      @@forgotten = {}
      JSONStorage.fetch 'reporter' do |forgotten|
        @@forgotten = forgotten
      end
    end
  end
end

Events.subscribe :reporter do |message|
  Reporter.load(message.status)
end
