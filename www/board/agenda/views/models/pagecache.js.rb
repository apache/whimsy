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
    return false unless defined? location

    unless location.protocol == 'https:' or location.hostname == 'localhost'
      return false
    end

    return false unless defined?(ServiceWorker) and defined?(navigator)

#   # disable service workers for the production server(s) for now.  See:
#   # https://lists.w3.org/Archives/Public/public-webapps/2016JulSep/0016.html
#   if location.hostname =~ /^whimsy.*\.apache\.org$/
#     unless location.hostname.include? '-test'
#       # unregister service worker
#       navigator.serviceWorker.getRegistrations().then do |registrations|
#         registrations.each do |registration|
#           registration.unregister()
#         end
#       end
#
#       return false
#     end
#   end

    return true
  end

  # registration and related startup actions
  def self.register()
    # register service worker
    scope = URL.new('..', document.getElementsByTagName('base')[0].href)
    navigator.serviceWorker.register(scope + 'sw.js', scope).then do
      # watch for reload requests from the service worker
      navigator.serviceWorker.addEventListener 'message' do |event|
        if event.data.type == 'reload'
          # ignore reload request if any input or textarea element is visible
          inputs = document.querySelectorAll('input, textarea')
          unless Array(inputs).map {|element| element.offsetWidth}.max() > 0
            window.location.reload() 
          end
        end
      end

      # preload agenda and referenced pages for next requeset
      base = document.getElementsByTagName('base')[0].href
      navigator.serviceWorker.ready.then do |registration|
        registration.active.postMessage type: 'preload',
          url: base + 'bootstrap.html'
      end
    end
  end
end
