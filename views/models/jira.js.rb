#
# Fetch, retain, and query the list of JIRA projects
#

class JIRA
  @@list = nil

  def self.find(name)
    if @@list
      return @@list.include? name
    elsif defined? XMLHttpRequest
      @@list = []
      fetch('jira', :json) do |list|
        @@list = list
        Main.refresh()
      end
    end
  end
end
