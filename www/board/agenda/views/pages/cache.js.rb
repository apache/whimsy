#
# A page showing status of caches and service workers
#

class CacheStatus < React
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
          _th 'Scope'
          _th 'Status'
        end

        _tbody @registrations do |registration|
          _tr do
            _td registration.scope
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

  # update on first update
  def componentDidMount()
    self.componentWillReceiveProps()
  end

  # update caches
  def componentWillReceiveProps()
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
end

#
# Individual Cache page
#

class CachePage < React
  def initialize
    @response = {}
    @text = ''
  end

  def render
    _h2 @response.url
    _p "#{@response.status} #{@response.statusText}"
    _pre @text
  end

  # update on first update
  def componentDidMount()
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
