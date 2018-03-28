#
# Fetch, retain, and query the list of feedback responses on board@
#

class Responses
  Vue.util.defineReactive @@list, nil

  def self.loading
    @@list and @@list.keys().empty?
  end

  def self.find(date, name)
    if @@list
      return @@list[date] and @@list[date][name]
    else
      @@list = {}
      JSONStorage.fetch 'responses' do |list|
        @@list = list
      end
    end
  end
end
