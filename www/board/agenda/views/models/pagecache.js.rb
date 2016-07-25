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

    return defined? ServiceWorker
  end

  # fetch and cache page and referenced scripts and stylesheets
  def self.preload()
    return unless PageCache.enabled?

    base = document.getElementsByTagName('base')[0].href
    fetch_options = {credentials: 'include'}

    fetch('bootstrap.html', fetch_options).then do |response|
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
          cache.put("#{agenda}.html", response)

          urls.each do |url|
            fetch(url.pathname, fetch_options).then do |response|
              basename = url.pathname.split('/').pop().split('?')[0]
              cache.put(basename, response)
            end
          end
        end
      end
    end
  end

end
