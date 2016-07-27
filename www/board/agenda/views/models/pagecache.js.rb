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

    # listen for events
    navigator.serviceWorker.addEventListener :message do |event|
      Events.dispatch event
    end
  end

  # fetch and cache page and referenced scripts and stylesheets
  def self.preload()
    return unless PageCache.enabled?

    base = document.getElementsByTagName('base')[0].href
    request = Request.new('bootstrap.html', credentials: 'include')

    fetch(request).then do |response|
      response.clone().text().then do |text|
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

        # add bootstrap.html and each URL to the cache.
        caches.open('board/agenda').then do |cache|
          agenda = Agenda.file[/\d+_\d+_\d+/].gsub('_', '-')
          cache.put(request, response)

          urls.each do |url|
            request2 = Request.new(url, credentials: 'include')
            fetch(request2).then {|response| cache.put(request2, response)}
          end
        end
      end
    end
  end

end
