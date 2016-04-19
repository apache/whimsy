#
# Fetch, retain, and query the list of historical comments
#

class HistoricalComments
  @@comments = nil

  # find historical comments based on report title
  def self.find(title)
    if @@comments
      return @@comments[title]
    elsif defined? XMLHttpRequest
      @@comments = JSONStorage.get('comments') || {}
      fetch('historical-comments', :json) do |comments|
        @@comments = JSONStorage.put('comments', comments) if comments
      end
    end
  end

  # find link for historical comments based on date and report title
  def self.link(date, title)
    if Server.agendas.include? "board_agenda_#{date}.txt"
      return "../#{date.gsub('_', '-')}/#{title}"
    else
      return "../../minutes/#{title}.html#minutes_#{date}"
    end
  end
end
