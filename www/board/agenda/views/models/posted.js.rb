# Posted PMC reports - see https://whimsy.apache.org/board/posted-reports

class Posted
  Vue.util.defineReactive @@list, []
  @@fetched = false

  def self.get(title)
    results = []

    # fetch list of reports on first reference
    if not @@fetched
      @@list = []
      JSONStorage.fetch 'posted-reports' do |list|
        @@list = list
      end

      @@fetched = true
    end

    # return list of matching reports
    @@list.each do |entry|
      results << entry if entry.title == title
    end

    return results
  end
end
