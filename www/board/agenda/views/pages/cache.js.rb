#
# A page showing status of caches and service workers
#

class CacheStatus < Vue
  def self.buttons()
    return [{button: ClearCache}, {button: UnregisterWorker}]
  end

  def initialize
    @cache = []
    @registrations = []
  end

  def render
    _h2 'Status'

    if defined? navigator and navigator.respond_to? :serviceWorker
      _p 'Service workers ARE supported by this browser'
    else
      _p 'Service workers are NOT supported by this browser'
    end

    _h2 'Cache'

    if @cache.empty?
      _p 'empty'
    else
      _ul @cache do |item|
        basename = item.split('/').pop()
        basename = 'index.html' if basename == ''
        basename = item.split('/')[-2] + '.html' if basename == 'bootstrap.html'
        _li {_Link text: item, href: "cache/#{basename}"}
      end
    end

    _h2 'Service Workers'

    if @registrations.empty?
      _p 'none found'
    else
      _table.table do
        _thead do
          _th 'URL'
          _th 'Scope'
          _th 'Status'
        end

        _tbody @registrations do |registration|
          _tr do
            _td do
              if registration.active
                _a registration.active.scriptURL,
                 href: registration.active.scriptURL
              end
            end

            _td do
              _a registration.scope, href: registration.scope
            end

            _td do
              if registration.installing
                _span 'installing'
              elsif registration.waiting
                _span 'waiting'
              elsif registration.active
                _span 'active'
              else
                _span 'unknown'
              end
            end
          end
        end
      end
    end

  end

  # update information
  def collect_data()
    if defined? caches
      caches.open('board/agenda').then do |cache|
        cache.matchAll().then do |responses|
          cache = responses.map {|response| response.url}
          cache.sort()
          @cache = cache
        end
      end

      navigator.serviceWorker.getRegistrations().then do |registrations|
        @registrations = registrations
      end
    end
  end

  def mounted()
    # initial observations
    collect_data()

    # update observations every 5 seconds
    CacheStatus.timer = setInterval 5_000 do
      collect_data()
    end

    # export method to allow update in response to button presses
    CacheStatus.collect_data = self.collect_data
  end

  def beforeDestroy()
    clearInterval CacheStatus.timer if CacheStatus.timer
    CacheStatus.timer = nil
  end
end

#
# A button that clear the cache
#
class ClearCache < Vue
  def render
    _button.btn.btn_primary 'Clear Cache', onClick: self.click
  end

  def click(event)
    if defined? caches
      caches.delete('board/agenda').then do |status|
        CacheStatus.collect_data()
      end
    end
  end
end

#
# A button that removes the service worker.  Sadly, it doesn't seem to have
# any affect on the list of registrations that is dynamically returned.
#
class UnregisterWorker < Vue
  def render
    _button.btn.btn_primary 'Unregister ServiceWorker', onClick: self.click
  end

  def click(event)
    if defined? caches
      navigator.serviceWorker.getRegistrations().then do |registrations|
        base = URL.new('..', document.getElementsByTagName('base')[0].href).href
        registrations.each do |registration|
          if registration.scope == base
            registration.unregister().then do |status|
              CacheStatus.collect_data()
            end
          end
        end
      end
    end
  end
end

#
# Individual Cache page
#

class CachePage < Vue
  def initialize
    @response = {}
    @text = ''
  end

  def render
    _h2 @response.url
    _p "#{@response.status} #{@response.statusText}"

    if @response.headers
      # avoid buggy @response.headers.keys()
      keys = []
      iterator = @response.headers.entries()
      entry = iterator.next()
      while not entry.done
        keys << entry.value[0] unless entry.value[0] == 'status'
        entry = iterator.next()
      end

      keys.sort()

      _ul do
        keys.each do |key|
          _li "#{key}: #{@response.headers.get(key)}"
        end
      end
    end

    _pre @text
  end

  # update on first update
  def mounted()
    if defined? caches
      basename = location.href.split('/').pop()
      basename = '' if basename == 'index.html'
      basename = 'bootstrap.html' if basename =~ /^\d+-\d+-\d+\.html$/

      caches.open('board/agenda').then do |cache|
        cache.matchAll().then do |responses|
          responses.each do |response|
            if response.url.split('/').pop() == basename
              @response = response
              response.text().then {|text| @text = text}
            end
          end
        end
      end
    end
  end
end
