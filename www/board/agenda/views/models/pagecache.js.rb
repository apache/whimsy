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
    # disable service workers for now.  See:
    # https://lists.w3.org/Archives/Public/public-webapps/2016JulSep/0016.html
    return false

    unless location.protocol == 'https:' or location.hostname == 'localhost'
      return false
    end

    defined?(ServiceWorker) and defined?(navigator)
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

    # forward service worker events
    navigator.serviceWorker.addEventListener :message do |event|
      Events.dispatch event.data
    end
  end

  # add/update bootstrap.html in the cache
  def self.preload()
    return unless PageCache.enabled?

    request = Request.new('bootstrap.html', credentials: 'include')

    fetch(request).then do |response|
      response.clone().text().then do |text|
        caches.open('board/agenda').then do |cache|
          cache.put(request, response)
        end
      end
    end
  end

end
