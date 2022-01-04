# encapsulate access to preferences

require 'yaml/store'
require_relative '../config.rb'

class Prefs

  def initialize()
    @name  = File.join(ARCHIVE,'prefs.yml')
    @store = YAML::Store.new(@name)
  end

  # Return the list of domains (xxx.apache.org etc)
  def [](id)
    @store.transaction do
      data = @store[id]
      data && data[:domains]
    end
  end

  # Store the list of domains (xxx.apache.org etc)
  def []=(id, domains)
    value = {
      last_updated: Time.now,
      domains: domains,
    }
    @store.transaction do
      @store[id]=value
    end
  end
end

if __FILE__ == $0
  prefs = Prefs.new
  puts prefs['test'].inspect
  prefs['test'] = [1,2,3]
  puts prefs['test'].inspect
end