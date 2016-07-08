#
# Fetch, retain, and query the list of JIRA projects
#

class JIRA
  @@list = nil

  def self.find(name)
    if @@list
      return @@list.include? name
    else
      @@list = []
      JSONStorage.fetch 'jira' do |list|
        @@list = list
      end
    end
  end
end
