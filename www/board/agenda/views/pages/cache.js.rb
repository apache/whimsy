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
        _li item
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
        @cache = cache.keys()
      end

      navigator.serviceWorker.getRegistrations().then do |registrations|
        @registrations = registrations
      end
    end
  end
end
