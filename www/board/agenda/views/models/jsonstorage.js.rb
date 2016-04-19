#
# Simplify access to localStorage for JSON objects
#

class JSONStorage
  # determine localStorage variable prefix based on url up to the date
  def self.prefix
    return @@prefix if @@prefix

    base = document.getElementsByTagName("base")[0].href
    origin = location.origin
    if not origin # compatibility: http://s.apache.org/X2L
      origin = window.location.protocol + "//" + window.location.hostname + 
        (window.location.port ? ':' + window.location.port : '')
    end

    @@prefix = base[origin.length..-1].sub(/\/\d{4}-\d\d-\d\d\/.*/, '').
      gsub(/^\W+|\W+$/, '').gsub(/\W+/, '_') || location.port
  end

  # store an item, converting it to JSON
  def self.put(name, value)
    name = JSONStorage.prefix + '-' + name
    localStorage.setItem(name, JSON.stringify(value))
    return value
  end

  # retrieve an item, converting it back to an object
  def self.get(name)
    if defined? localStorage
      name = JSONStorage.prefix + '-' + name
      return JSON.parse(localStorage.getItem(name) || 'null')
    end
  end
end
