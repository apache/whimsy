# Posted PMC reports - see https://whimsy.apache.org/board/posted-reports

class Posted
  @@list = []
  @@fetched = false

  def self.get(title)
    results = []

    # fetch list of reports on first reference
    if not @@fetched and defined? XMLHttpRequest
      @@list = JSONStorage.get('posted') || []
      fetch 'https://whimsy.apache.org/board/posted-reports', :json do |list|
        @@list = JSONStorage.put('posted', list) if list
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
