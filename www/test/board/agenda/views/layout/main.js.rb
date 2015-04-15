#
# Main component, responsible for:
#
#  * Initial loading and polling of the agenda
#
#  * Rendering a Header, a item view, and a Footer
#
#  * Resizing view to leave room for the Header and Footer
#

class Main < React

  # initialize polling state
  def initialize
    @poll = {
      link: "../#{@@page.date}.json",
      etag: @@page.etag,
      interval: 10_000
    }
  end

  # common layout for all pages: header, main, footer, and forms
  def render
    if not @item
      _p 'Not found'
    else

      _Header item: @item

      view = nil
      _main do
        React.createElement(@item.view, item: @item, 
         ref: proc {|component| Main.view=component})
      end

      _Footer item: @item, buttons: Router.buttons

      # emit hidden forms associated with the buttons displayed on this page
      if @item.buttons
        @item.buttons.each do |button|
          if button.form
            React.createElement(button.form, item: @item, server: Server,
              button: button)
          end
        end
      end
    end
  end

  # initial load of the agenda, and route first request
  def componentWillMount()
    # copy server info for later use
    for prop in @@server
      Server[prop] = @@server[prop]
    end

    Agenda.load(@@page.parsed)
    Agenda.date = @@page.date
    @item = Router.route(@@page.path, @@page.query)

    # free memory
    @@page.parsed = nil
  end

  # navigation method that updates history (back button) information
  def navigate(path, query)
    @item = Router.route(path, query)
    history.pushState({path: path, query: query}, nil, path)
  end

  # refresh the current page
  def refresh()
    @item = Router.route(history.state.path, history.state.query)
  end

  # dummy exported refresh method (replaced on client side)
  def self.refresh()
  end

  # additional client side initialization
  def componentDidMount()
    # export navigate and refresh methods
    Main.navigate = self.navigate
    Main.refresh  = self.refresh

    # store initial state in history, taking care not to overwrite
    # history set by the Search component.
    if not history.state or not history.state.query
      history.replaceState({path: @@page.path}, nil, @@page.path)
    end

    # listen for back button, and re-route/re-render when it occcurs
    window.addEventListener :popstate do |event|
      if event.state and defined? event.state.path
        @item = Router.route(event.state.path, event.state.query)
      end
    end

    # track control key
    def (document.body).onkeyup(event)
      if Keyboard.control != event.ctrlKey
        Keyboard.control = event.ctrlKey
        Main.refresh()
      end
    end

    # track control key + keyboard navigation (unless on the search screen)
    def (document.body).onkeydown(event)
      if Keyboard.control != event.ctrlKey
        Keyboard.control = event.ctrlKey
        Main.refresh()
      end

      return if ~'#search-text' or ~'.modal-open'
      return if event.metaKey or event.ctrlKey

      if event.keyCode == 37 # '<-'
        link = ~"a[rel=prev]"
        if link
          self.navigate link.getAttribute('href')
          window.scrollTo(0, 0)
          return false
        end
      elsif event.keyCode == 39 # '->'
        link = ~"a[rel=next]"
        if link
          self.navigate link.getAttribute('href')
          window.scrollTo(0, 0)
          return false
        end
      elsif event.keyCode == 13 # 'enter'
        link = ~".default"
        self.navigate link.getAttribute('href') if link
        return false
      elsif event.keyCode == 'C'.ord
        link = ~"#comments"
        link.scrollIntoView() if link
        return false
      elsif event.keyCode == 'I'.ord
        link = ~"#info"
        link.click() if link
        return false
      elsif event.keyCode == 'N'.ord
        link = ~"#nav"
        link.click() if link
        return false
      elsif event.keyCode == 'A'.ord
        link = ~"#agenda"
        link.click() if link
        return false
      elsif event.keyCode == 'S'.ord
        link = ~"#shepherd"
        link.click() if link
        return false
      elsif event.keyCode == 'Q'.ord
        link = ~"#queue"
        link.click() if link
        return false
      elsif event.shiftKey and event.keyCode == 191 # "?"
        link = ~"#help"
        link.click() if link
        return false
      elsif event.keyCode == 'R'.ord
        clock_counter += 1
        Main.refresh()
        post 'refresh', agenda: Agenda.file do |response|
          clock_counter -= 1
          Agenda.load response.agenda
          Main.refresh()
        end
        return false
      end
    end

    # whenever the window is resized, adjust margins of the main area to
    # avoid overlapping the header and footer areas
    def window.onresize()
      main = ~'main'
      main.style.marginTop = "#{~'header.navbar'.clientHeight}px"
      main.style.marginBottom = "#{~'footer.navbar'.clientHeight}px"
    end

    # do an initial resize
    window.onresize()

    # if agenda is stale, fetch immediately; start polling agenda
    self.fetchAgenda() unless @poll.etag
    setInterval self.fetchAgenda, @poll.interval
  end

  # after each subsequent re-rendering, resize main window
  def componentDidUpdate()
    window.onresize()
  end

  # fetch agenda
  def fetchAgenda()
    xhr = XMLHttpRequest.new()
    xhr.open('GET', @poll.link, true)
    xhr.setRequestHeader('If-None-Match', @poll.etag) if @poll.etag
    xhr.responseType = 'text'
    def xhr.onreadystatechange()
      if xhr.readyState == 4 and xhr.status == 200 and xhr.responseText != ''
        @poll.etag = xhr.getResponseHeader('ETag')
        Agenda.load(JSON.parse(xhr.responseText))
        @item = Router.route(history.state.path, history.state.query)
      end
    end
    xhr.send()
  end
end
