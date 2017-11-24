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
#      the cache, it is fetched and the results are cached.
#
#   *) Requests for javascript and stylesheets are cached and used to
#      respond to fetches that fail
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

# look for css and js files and ensure that each are cached
def preload(cache, base, text)
  pattern = Regexp.new('"[-.\w+/]+\.(css|js)\?\d+"', 'g')

  while (match = pattern.exec(text))
    path = match[0].slice(1).split('?')[0]
    request = Request.new(URL.new(path, base))
    cache.match(request).then do |response|
      if not response
        fetch(request).then do |response|
          cache.put(request, response) if response.ok
        end
      end
    end
  end
end

# respond with bootstrap fetch patch
self.addEventListener :fetch do |event|
  scope = self.registration.scope
  url = event.request.url
  url = url.slice(scope.length) if url.start_with? scope

  if event.request.method == 'GET'
    return if url.end_with? '/bootstrap.html'

    # determine what url to fetch (if any)
    if url =~ %r{^\d\d\d\d-\d\d-\d\d/[-\w]*$}
      # substitute bootstrap.html for html pages
      return unless event.request.mode == 'navigate'
      date =  url.split('/')[0]
      bootstrap = "#{scope}#{date}/bootstrap.html"
      fetch_request = Request.new(bootstrap, cache: "no-store")
      cache_request = fetch_request
    elsif url =~ %r{\.(js|css)\?\d+$}
      # cache and respond to js and css requests
      fetch_request = event.request
      cache_request = Request.new(url.split('?')[0], cache: "no-store")
    else
      return
    end

    # produce response
    event.respondWith(
      Promise.new do |fulfill, reject|
        timeoutId = nil

        caches.open('board/agenda').then do |cache|
          # common logic to reply from cache
          replyFromCache = lambda do
            timeoutId = nil
            cache.match(cache_request).then do |response|
              if response
                fulfill response
              else
                fetch(event.request).then(fulfill, reject)
              end
            end
          end

          # respond from cache if the server isn't fast enough
          timeoutId = setTimeout(replyFromCache, timeout)

          # fetch bootstrap.html or stylesheet or javascript
          fetch(fetch_request).then {|response|
            # cache the response if OK, fulfill the response if not timed out
            if response.ok
              cache.put(cache_request, response.clone())

              if fetch_request.url =~ /bootstrap\.html$/
                response.clone().text().then do |text|
                  preload(cache, fetch_request.url, text)
                end
              end

              if timeoutId
                clearTimeout timeoutId 
                fulfill response
              end
            else
              # bad response: use cache instead
              replyFromCache()
            end
          }.catch {|failure|
            # no response: use cache instead
            replyFromCache()
          }
        end
      end
    )
  end
end
