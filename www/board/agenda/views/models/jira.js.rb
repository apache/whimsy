#
# Fetch, retain, and query the list of JIRA projects
#

class JIRA
  @@list = nil

  def self.find(name)
    if @@list
      return @@list.include? name
    elsif defined? XMLHttpRequest
      @@list = JSONStorage.get('jira') || []
      fetch('jira', :json) do |list|
        @@list = JSONStorage.put('jira', list) if list
      end
    end
  end
end
