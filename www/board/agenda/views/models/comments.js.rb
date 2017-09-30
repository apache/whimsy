#
# Fetch, retain, and query the list of historical comments
#

class HistoricalComments
  Vue.util.defineReactive @@comments, nil

  # find historical comments based on report title
  def self.find(title)
    if @@comments
      return @@comments[title]
    else
      @@comments = {}
      JSONStorage.fetch('historical-comments') do |comments|
        @@comments = comments || {}
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
