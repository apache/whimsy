#
# Fetch, retain, and query the list of JIRA projects
#

class JIRA
  Vue.util.defineReactive @@list, nil

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
