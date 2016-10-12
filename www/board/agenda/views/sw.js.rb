#
# A very simple service worker
#
#   *) Return back cached bootstrap page instead of fetching agenda pages
#      from the network.  Bootstrap will construct page from cached
#      agenda.json, as well as update the cache.
# 

self.addEventListener :fetch do |event|
  scope = self.registration.scope
  url = event.request.url
  url = url.slice(scope.length) if url.start_with? scope

  if url =~ %r{^\d\d\d\d-\d\d-\d\d/} and event.request.method == 'GET'
    event.respondWith(
      caches.open('board/agenda').then do |cache|
        date =  url.split('/')[0]
        return cache.match("#{date}/bootstrap.html").then do |response|
          return response || fetch(event.request.url, credentials: 'include')
        end
      end
    )
  end
end
