#
# A very simple service worker
#
#   *) Replace calls to fetch an agenda page with calls to fetch a bootstrap
#      page.   This page will reconstruct the page requested using cached
#      data and then request fresh data.  If the server doesn't respond
#      with 0.5 seconds or fails, return a cached version of the bootstrap
#      page.
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

# respond with bootstrap fetch patch
self.addEventListener :fetch do |event|
  scope = self.registration.scope
  url = event.request.url
  url = url.slice(scope.length) if url.start_with? scope

  if url =~ %r{^\d\d\d\d-\d\d-\d\d/[-\w]*$} and event.request.method == 'GET'
    return unless event.request.mode == 'navigate'
    return if url.end_with? '/bootstrap.html'

    event.respondWith(
      Promise.new do |fulfill, reject|
        date =  url.split('/')[0]
        bootstrap = "#{scope}/#{date}/bootstrap.html"
        request = Request.new(bootstrap, cache: "no-store")
        error = nil
        timeoutId = nil

        caches.open('board/agenda').then do |cache|
          # respond from cache if the server isn't fast enough
          timeoutId = setTimeout timeout do
            timeoutId = nil
            cache.match(request).then do |response|
              if response
                fulfill response
              else
                fetch(event.request).then(fulfill, reject)
              end
            end
          end

          # fetch bootstrap.html
          fetch(request).then {|response|
            # cache the response if OK, fulfull the response if not timed out
            if response.ok
              cache.put(request, response.clone())
              if timeoutId
                clearTimeout timeoutId 
                fulfill response
              end
            end
          }.catch {|failure|
            # fetch rejected before the timeout
            if timeoutId
              clearTimeout timeoutId 
              reject failure 
            end
          }
        end
      end
    )
  end
end
