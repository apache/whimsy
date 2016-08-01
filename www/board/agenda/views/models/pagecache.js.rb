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

    # disable service workers for the production server(s) for now.  See:
    # https://lists.w3.org/Archives/Public/public-webapps/2016JulSep/0016.html
    if location.hostname =~ /^whimsy.*\.apache\.org$/
      return false unless location.hostname.include? '-test'
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

  # aggressively attempt to preload pages directly used by the agenda pages
  # into the appropriate cache.
  def self.preload()
    return unless PageCache.enabled?

    request = Request.new('bootstrap.html', credentials: 'include')
    fetch(request).then do |response|

      # add/update bootstrap.html in the cache
      caches.open('board/agenda').then do |cache|
        cache.put(request, response.clone())
      end

      urls = []

      # search body text for scripts
      script = Regexp.new(/<script.*?>/, 'g')
      matches = text.match(script)
      matches.each do |match|
        src = match.match(/src="(.*?)"/)
        urls << URL.new(src[1], base) if src
      end

      # search body text for links to stylesheets
      links = Regexp.new(/<link.*?>/, 'g')
      matches = text.match(links)
      matches.each do |match|
        href = match.match(/href="(.*?)"/)
        urls << URL.new(href[1], base) if href
      end

      # update browser cache with latest scripts and stylesheets.  Note: no
      # network requests will be made if these pages are up to date
      urls.each do |url|
        fetch(Request.new(url, credentials: 'include'))
      end
    end
  end

end
