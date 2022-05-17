#
# A cache of agenda related pages, useful for:
#
#  1) quick loading of possibly stale data, which will be updated with
#     current information as it becomes available.
#
#  2) offline access to the agenda tool
#

class PageCache
  Vue.util.defineReactive @@installPrompt, nil

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

    return defined? navigator.serviceWorker
  end

  # registration and related startup actions
  def self.register()
    # register service worker
    scope = URL.new('..', document.getElementsByTagName('base')[0].href)
    swjs = "#{scope}sw.js?#{Server.swmtime}"
    navigator.serviceWorker.register(swjs, scope).then do
      # watch for reload requests from the service worker
      navigator.serviceWorker.addEventListener 'message' do |event|
        # ignore requests if any input or textarea element is visible
        inputs = document.querySelectorAll('input, textarea')
        unless Array(inputs).map {|element| element.offsetWidth}.max() > 0
          if event.data.type == 'reload'
            window.location.reload()
          elsif event.data.type == 'latest' and Main.latest
            self.latest(event.data.body)
          end
        end
      end

      # preload agenda and referenced pages for next request
      base = document.getElementsByTagName('base')[0].href
      navigator.serviceWorker.ready.then do |registration|
        registration.active.postMessage type: 'preload',
          url: base + 'bootstrap.html'
      end
    end

    # fetch bootstrap from server, and update latest once it is received
    if Main.item == Agenda and Main.latest
      fetch('bootstrap.html').then do |response|
        response.text().then do |body|
          self.latest(body)
        end
      end
    end

    window.addEventListener :beforeinstallprompt do |event|
      @@installPrompt = event
      Main.refresh() if Main.item.view == Help
      event.preventDefault();
    end

    self.cleanup(scope.toString(), Server.agendas)
  end

  # remove cached pages associated with agendas that are no longer present
  def self.cleanup(scope, agendas)
    agendas = agendas.map {|agenda| agenda[/\d\d\d\d_\d\d_\d\d/].gsub('_', '-')}

    caches.open('board/agenda').then do |cache|
      cache.matchAll().then do |responses|
        urls = responses.map {|response| response.url}.select do |url|
          part = url[scope.length..-1].split('/')[0].split('.')[0]
         part =~ /^\d\d\d\d-\d\d-\d\d$/ && !agendas.include?(part)
        end

        urls.each do |url|
          cache.delete(url).then {}
        end
      end
    end
  end

  # if the entry point URL is /latest/, the service worker will optimistically
  # show the latest known agenda. If it turns out that there is a later one,
  # refresh with that page.
  def self.latest(body)
    # ignore requests if any input or textarea element is visible
    inputs = document.querySelectorAll('input, textarea')
    return if Array(inputs).map {|element| element.offsetWidth}.max() > 0

    latest = nil
    data = body[/"agendas":\[.*?\]/]

    agenda_re = Regexp.new('board_agenda_\d\d\d\d_\d\d_\d\d.txt', 'g')
    while agenda = agenda_re.exec(data)
      latest = agenda[0] unless latest and latest > agenda[0]
    end

    if latest and latest != Agenda.file
      date = latest[/\d\d\d\d_\d\d_\d\d/].gsub('_', '-')
      window.location.href = "../#{date}/"
    end
  end

  # install prompt support
  def self.installPrompt
    @@installPrompt
  end

  def self.installPrompt=(value)
    @@installPrompt = value
  end
end
