#
# Originally defined to simplify access to sessionStorage for JSON objects.
#
# Now expanded to include caching using fetch and the cache defined in
# the Service Workers specification (but without the user of SWs).
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

  # retrieve an cached object.  Note: block may be dispatched twice,
  # once with slightly stale data and once with current data
  #
  # Note: caches only work currently on Firefox and Chrome.  All
  # other browsers fall back to XMLHttpRequest (AJAX).
  def self.fetch(name, &block)

    if
      defined? fetch and defined? caches and
      (location.protocol == 'https:' or location.hostname == 'localhost')
    then
      caches.open('board/agenda').then do |cache|
        fetched = nil
        Header.clock_counter += 1

        # construct request
        request = Request.new("../json/#{name}", method: 'get',
          credentials: 'include', headers: {'Accept' => 'application/json'})

        # dispatch request
        fetch(request).then do |response|
          cache.put(request, response.clone())

          response.json().then do |json|
            unless fetched and fetched.inspect == json.inspect
              Header.clock_counter -= 1 unless fetched
              fetched = json
              block(json) if json
              Main.refresh()
            end
          end
        end

        # check cache
        cache.match("../json/#{name}").then do |response|
          if response and not fetched
            response.json().then do |json|
              Header.clock_counter -= 1
              fetched = json
              block(json) if json
              Main.refresh()
            end
          end
        end
      end

    elsif defined? XMLHttpRequest

      # retrieve from the network only
      retrieve name, :json, block

    end
  end
end
