#
# Simplify access to sessionStorage for JSON objects
#

class JSONStorage
  # determine sessionStorage variable prefix based on url up to the date
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
    begin
      sessionStorage.setItem(name, JSON.stringify(value))
    rescue => e
    end
    return value
  end

  # retrieve an item, converting it back to an object
  def self.get(name)
    if defined? sessionStorage
      name = JSONStorage.prefix + '-' + name
      return JSON.parse(sessionStorage.getItem(name) || 'null')
    end
  end
end
