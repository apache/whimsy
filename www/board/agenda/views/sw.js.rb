#
# A service worker that bootstraps the board agenda application
#
#   *) Replace calls to fetch any agenda page with calls to fetch a bootstrap
#      page.   This page will reconstruct the page requested using cached
#      data and then request fresh data.  If the server doesn't respond
#      with 0.5 seconds or fails, return a cached version of the bootstrap
#      page.
#
#   *) When a bootstrap.html page is loaded, a scan is made for references
#      to javascripts and stylesheets, and if such a page is not present in
#      the cache, it is fetched and the results are cached.  This is because
#      browsers will sometimes try to request these pages -- even when marked
#      as immutable -- when offline.
#
#   *) Requests for javascript and stylesheets are cached and used to
#      respond to fetches that fail.  Once a new response is received,
#      old responses (with different query strings) are deleted.
# 

timeout = 500

# install immediately
self.addEventListener :install do
  return self.skipWaiting()
end

# take over responsibility for existing clients
# https://developer.mozilla.org/en-US/docs/Web/API/Clients/claim
self.addEventListener :activate do |event|
  event.waitUntil self.clients.claim();
end

# insert or replace a response into the cache.  Delete other responses
# with the same path (ignoring the query string).
def cache_replace(cache, request, response)
  path = request.url.split('?')[0]
  cache.keys!().then do |keys|
    keys.each do |key|
      if key.url.split('?')[0] == path and key.url != path
        cache.delete(key).then {} 
      end
    end
  end

  cache.put(request, response)
end

# look for css and js files and in HTML response ensure that each are cached
def preload(cache, base, text)
  pattern = Regexp.new('"[-.\w+/]+\.(css|js)\?\d+"', 'g')

  while (match = pattern.exec(text))
    path = match[0].split('"')[1]
    request = Request.new(URL.new(path, base))
    cache.match(request).then do |response|
      if not response
        fetch(request).then do |response|
          cache_replace(cache, request, response) if response.ok
        end
      end
    end
  end
end

# fetch from cache with a network fallback
def fetch_from_cache(event)
  return caches.open('board/agenda').then do |cache|
    return cache.match(event.request).then do |response|
      return response || fetch(event.request).then do |response|
        cache_replace(cache, event.request, response.clone()) if response.ok
        return response
      end
    end
  end
end

# Return a bootstrap.html page within 0.5 seconds.  If the network responds
# in time, go with that response, otherwise respond with a cached version.
def bootstrap(event, request)
  return Promise.new do |fulfill, reject|
    timeoutId = nil

    caches.open('board/agenda').then do |cache|
      # common logic to reply from cache
      replyFromCache = lambda do |refetch|
	cache.match(request).then do |response|
	  clearTimeout timeoutId

	  if response
	    fulfill response
	    timeoutId = nil
	  elsif refetch
	    fetch(event.request).then(fulfill, reject)
	  end
	end
      end

      # respond from cache if the server isn't fast enough
      timeoutId = setTimeout timeout do
	replyFromCache(false)
      end

      # attach to fetch bootstrap.html from the network
      fetch(request).then {|response|
	# cache the response if OK, fulfill the response if not timed out
	if response.ok
	  cache.put(request, response.clone())

          # preload stylesheets and javascripts
	  if request.url =~ /bootstrap\.html$/
	    response.clone().text().then do |text|
	      setTimeout 3_000 do
		preload(cache, request.url, text)
	      end
	    end
	  end

	  if timeoutId
	    clearTimeout timeoutId 
	    fulfill response
	  end
	else
	  # bad response: use cache instead
	  replyFromCache(true)
	end
      }.catch {|failure|
	# no response: use cache instead
	replyFromCache(true)
      }
    end
  end
end

# interept selected pages
self.addEventListener :fetch do |event|
  scope = self.registration.scope
  url = event.request.url
  url = url.slice(scope.length) if url.start_with? scope

  if event.request.method == 'GET'
    return if url.end_with? '/bootstrap.html'

    # determine what url to fetch (if any)
    if url.end_with? '/bootstrap.html'
      return

    elsif url =~ %r{^\d\d\d\d-\d\d-\d\d/[-\w]*$}
      # substitute bootstrap.html for html pages
      date =  url.split('/')[0]
      bootstrap_url = "#{scope}#{date}/bootstrap.html"
      request = Request.new(bootstrap_url, cache: "no-store")

      # produce response
      event.respondWith(bootstrap(event, request))

    elsif url =~ %r{\.(js|css)\?\d+$}
      # cache and respond to js and css requests
      event.respondWith(fetch_from_cache(event))

    end
  end
end
