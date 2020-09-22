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
#   *) Inform clients of the need to reload if a slow server caused
#      pages to be loaded with stale scripts and/or stylesheets
#
#   *) when requested to do so by a client, preload additional pages.  This
#      is for the initial installation, as the pages will have already been
#      loaded by the browser.
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

# broadcast a message to all clients
def broadcast(message)
  clients.matchAll().then do |clients|
    clients.each do |client|
      client.postMessage(message)
    end
  end
end

# look for css and js files and in HTML response ensure that each are cached
def preload(cache, base, text, toolate)
  pattern = Regexp.new('"[-.\w+/]+\.(css|js)\?\d+"', 'g')

  count = 0
  changed = false
  while (match = pattern.exec(text))
    count += 1
    path = match[0].split('"')[1]
    request = Request.new(URL.new(path, base))
    cache.match(request).then do |response|
      if response
        count -= 1
      else
        changed = true
        fetch(request).then do |response|
          cache_replace(cache, request, response) if response.ok
          count -= 1
          broadcast(type: 'reload') if toolate and changed and count == 0
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

# Return latest bootstrap page from the cache; then update the bootstrap
# from the server.  If the body has changed, broadcast that information to
# all the browser window clients.
def latest(event)
  return Promise.new do |fulfill, reject|
    caches.open('board/agenda').then do |cache|
      cache.matchAll().then do |responses|
        match = nil
        responses.each do |response|
          if response.url.end_with? '/bootstrap.html'
            match = response if not match or match.url < response.url
          end
        end

        if match
          match.clone().text().then do
            fulfill(match)

            request = Request.new(match.url, cache: "no-store")
            fetch(request).then do |response|
              if response.ok
                response.clone().text().then do |after|
                  cache.put request, response
                  broadcast(type: 'latest', body: after) # if after != before
                end
              end
            end
          end
        else
          fetch(event.request).then(fulfill, reject)
        end
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

      # attempt to fetch bootstrap.html from the network
      fetch(request).then {|response|
        # cache the response if OK, fulfill the response if not timed out
        if response.ok
          cache.put(request, response.clone())

          # preload stylesheets and javascripts
          if request.url =~ /bootstrap\.html$/
            response.clone().text().then do |text|
              toolate = !timeoutId
              setTimeout(toolate ? 0 : 3_000) do
                preload(cache, request.url, text, toolate)
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
      }.catch { |_failure|
        # no response: use cache instead
        replyFromCache(true)
      }
    end
  end
end

# intercept selected pages
self.addEventListener :fetch do |event|
  scope = self.registration.scope
  url = event.request.url
  url = url.slice(scope.length) if url.start_with? scope

  if event.request.method == 'GET'
    # determine what url to fetch (if any)
    if url.end_with? '/bootstrap.html'
      return

    elsif url =~ %r{^\d\d\d\d-\d\d-\d\d/(\w+/)?[-\w]*$}
      # substitute bootstrap.html for html pages
      date =  url.split('/')[0]
      bootstrap_url = "#{scope}#{date}/bootstrap.html"
      request = Request.new(bootstrap_url, cache: "no-store")

      # produce response
      event.respondWith(bootstrap(event, request))

    elsif url =~ %r{\.(js|css)\?\d+$}
      # cache and respond to js and css requests
      event.respondWith(fetch_from_cache(event))

    elsif url == ''
      # event.respondWith(Response.redirect('latest/'))

    elsif url == 'latest/'
      event.respondWith(latest(event))
    end
  end
end

# watch for preload requests
self.addEventListener :message do |event|
  if event.data.type == :preload
    caches.open('board/agenda').then do |cache|
      request = Request.new(event.data.url, cache: "no-store")
      cache.match(request).then do |response|
        unless response
          fetch(request).then do |response|
            if response.ok
              response.text().then do |text|
                preload(cache, request.url, text, false)
              end
            end
          end
        end
      end
    end
  end
end
