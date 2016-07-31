#
# A very simple service worker
#
#   1) Create an event source and pass all events received to all clients
#
#   2) Return back cached bootstrap page instead of fetching agenda pages
#      from the network.  Bootstrap will construct page from cached
#      agenda.json, as well as update the cache.
#
#   3) For all other pages, serve cached content when offline
# 

events = nil

self.addEventListener :activate do |event|
  # close any pre-existing event socket
  if events
    begin
      events.close()
    rescue => e
      events = nil
    end
  end
 
  # create a new event source
  events = EventSource.new('events')
 
  # dispatch any events received to clients
  events.addEventListener :message do |event|
    clients.matchAll().then do |list|
      list.each do |client|
        client.postMessage(event.data)
      end
    end
  end
end

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
  elsif false #disable for now
    event.respondWith(
      fetch(event.request, credentials: 'include').catch do |error|
        return caches.open('board/agenda').then do |cache|
          return cache.match(event.request) do |response|
            return response || error
          end
        end
      end
    )
  end
end
