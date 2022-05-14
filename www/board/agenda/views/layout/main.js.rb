#
# Main component, responsible for:
#
#  * Initial loading and polling of the agenda
#
#  * Rendering a Header, a item view, and a Footer
#
#  * Resizing view to leave room for the Header and Footer
#

class Main < Vue
  # common layout for all pages: header, main, footer, and forms
  def render
    if not @item
      _p 'Not found'
    else

      _Header item: @item

      _main do
        if Agenda.index[0].text # don't display page while bootstrapping
          Vue.createElement(@item.view, props: {item: @item}, ref: 'view')
        end
      end

      _Footer item: @item, buttons: @buttons, options: @options

      # emit hidden forms associated with the buttons displayed on this page
      if @buttons
        @buttons.each do |button|
          if button.form
            Vue.createElement(button.form, props: {item: @item, server: Server,
              button: button})
          end
        end
      end
    end
  end

  # initial load of the agenda, and route first request
  def created()
    # copy server info for later use
    @@server.each_pair do |prop, value|
      Server[prop] = value
    end

    Pending.fetch() if PageCache.enabled or not Server.userid
    Agenda.load(@@page.parsed, @@page.digest)
    Minutes.load(@@page.minutes)
    Reporter.fetch() if PageCache.enabled

    self.route(@@page.path, @@page.query)

    # free memory
    @@page.parsed = nil
  end

  # encapsulate calls to the router
  def route(path, query)
    route = Router.route(path,query)

    @item = route.item
    @buttons = route.buttons
    @options = route.options

    unless Main.item and route.item and Main.item.view == route.item.view
      Main.view = nil
    end

    Main.item = route.item

    # update title to match the item title whenever page changes
    if defined? document and route.item
      date = Agenda.date
      title = route.item.title
      if date != title # don't duplicate the date
        document.getElementsByTagName('title')[0].textContent = date + ' ' + title
      else
        document.getElementsByTagName('title')[0].textContent = title
      end
    end
  end

  # navigation method that updates history (back button) information
  def navigate(path, query)
    history.state.scrollY = window.scrollY
    history.replaceState(history.state, nil, history.path)
    Main.scrollTo = 0
    self.route(path, query)
    history.pushState({path: path, query: query}, nil, path)
    window.onresize()
    Main.latest = false if path
  end

  # refresh the current page
  def refresh()
    self.route(history.state.path, history.state.query)
  end

  # dummy exported refresh method (replaced on client side)
  def self.refresh()
  end

  # additional client side initialization
  def mounted()
    # export navigate and refresh methods as well as view
    Main.navigate = self.navigate
    Main.refresh  = self.refresh
    Main.view  = $refs.view
    Main.item = Agenda

    # store initial state in history, taking care not to overwrite
    # history set by the Search component.
    if not history.state or not history.state.query
      path = @@page.path

      if path == 'bootstrap.html'
        path = document.location.href
        base = document.getElementsByTagName('base')[0].href
        if path.start_with? base
          path = path.slice(base.length)
        elsif path.end_with? '/latest/'
          Main.latest = true
          path = '.'
        end
      end

      history.replaceState({path: path}, nil, path)
    end

    # listen for back button, and re-route/re-render when it occurs
    window.addEventListener :popstate do |event|
      if event.state and defined? event.state.path
        Main.scrollTo = event.state.scrollY || 0
        self.route(event.state.path, event.state.query)
      end
    end

    # start watching keystrokes and fingers
    Keyboard.initEventHandlers()
    Touch.initEventHandlers()

    # whenever the window is resized, adjust margins of the main area to
    # avoid overlapping the header and footer areas
    def window.onresize()
      main = document.querySelector('main')
      return unless main

      footer = document.querySelector('footer')
      header = document.querySelector('header')
      if
        window.innerHeight <= 400 and
        document.body.scrollHeight > window.innerHeight
      then
        footer.style.position = 'relative' if footer
        header.style.position = 'relative' if header
        main.style.marginTop = 0
        main.style.marginBottom = 0
      else
        footer.style.position = 'fixed' if footer
        header.style.position = 'fixed' if header
        main.style.marginTop =
          "#{document.querySelector('header.navbar').clientHeight}px"
        main.style.marginBottom =
          "#{document.querySelector('footer.navbar').clientHeight}px"
      end

      if Main.scrollTo == 0 or Main.scrollTo
        if Main.scrollTo == -1
          jQuery('html, body').
            animate({scrollTop: document.documentElement.scrollHeight}, :fast)
        else
          window.scrollTo(0, Main.scrollTo)
          Main.scrollTo = nil
        end
      end
    end

    # do an initial resize
    Main.scrollTo = 0
    window.onresize()

    # if agenda is stale, fetch immediately; otherwise save etag
    Agenda.fetch(@@page.etag, @@page.digest)

    # start Service Worker
    PageCache.register() if PageCache.enabled

    # start backchannel
    Events.monitor()
  end

  # after each subsequent re-rendering, resize main window
  def updated()
    window.onresize()
  end
end
