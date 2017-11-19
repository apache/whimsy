#
# A cache of agenda related pages, useful for:
#
#  1) quick loading of possibly stale data, which will be updated with
#     current information as it becomes available.
#
#  2) offline access to the agenda tool
#

class PageCache

  # is page cache available?
  def self.enabled
    unless location.protocol == 'https:' or location.hostname == 'localhost'
      return false
    end

    return false unless defined?(ServiceWorker) and defined?(navigator)

    # disable service workers for the production server(s) for now.  See:
    # https://lists.w3.org/Archives/Public/public-webapps/2016JulSep/0016.html
    if location.hostname =~ /^whimsy.*\.apache\.org$/
      unless location.hostname.include? '-test'
        # unregister service worker
        navigator.serviceWorker.getRegistrations().then do |registrations|
          registrations.each do |registration|
            registration.unregister()
          end
        end

        return false
      end
    end

    return true
  end

  # registration and related startup actions
  def self.register()
    # preload page cache once page finishes loading
    window.addEventListener :load do |event|
      PageCache.preload()
    end

    # register service worker
    scope = URL.new('..', document.getElementsByTagName('base')[0].href)
    navigator.serviceWorker.register(scope + 'sw.js', scope)
  end

  # ensure that bootstrap.html is in the cache
  # into the appropriate cache.
  def self.preload()
    return unless PageCache.enabled?

    caches.open('board/agenda').then do |cache|
      # add bootstrap.html to the cache
      base = document.getElementsByTagName('base')[0].href
      request = Request.new(base + 'bootstrap.html', cache: "no-store")
      cache.match(request).then do |response|
        unless response
          fetch(request).then do |response|
            cache.put(request, response)
          end
        end
      end
    end
  end

end
