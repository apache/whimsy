#
# Main component, responsible for:
#
#  * Initial loading and polling of the agenda
#
#  * Routing based on path and query information in the URL
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

  # route request based on path and query from the window location (URL)
  def route(path, query)
    @traversal = :agenda

    if path == 'search'
      item = {view: Search, query: query}
    elsif path == 'comments'
      item = {view: Comments}
    elsif path == 'queue'
      buttons = []
      buttons << {form: Commit} if Pending.count > 0
      item = {view: Queue, buttons: buttons,
        title: 'Queued approvals and comments'}
    elsif not path or path == '.'
      item = Agenda
    elsif path =~ %r{^queue/[-\w]+$}
      @traversal = :queue
      item = Agenda.find(path[6..-1])
    elsif path =~ %r{^shepherd/queue/[-\w]+$}
      @traversal = :shepherd
      item = Agenda.find(path[15..-1])
    elsif path =~ %r{^shepherd/\w+$}
      shepherd = path[9..-1]
      item = {view: Shepherd, shepherd: shepherd,
        title: "Shepherded by #{shepherd}"}
    else
      item = Agenda.find(path)
    end

    # bail unless an item was found
    return unless item

    # provide defaults for required properties
    item.color ||= 'blank'
    item.title ||= item.view.displayName

    # determine what buttons are required, merging defaults, form provided
    # overrides, and any overrides provided by the agenda item itself
    buttons = item.buttons
    if buttons
      @buttons = buttons.map do |button|
        props = {text: 'button', attrs: {className: 'btn'}}

        # form overrides
        form = button.form
        if form and form.button
          for name in form.button
            if name == 'text'
              props.text = form.button.text
            elsif name == 'class' or name == 'classname'
              props.attrs.className += " #{form.button[name].gsub('_', '-')}"
            else
              props.attrs[name.gsub('_', '-')] = form.button[name]
            end
          end
        else
          # no form or form has no separate button: so this is just a button
          props.delete 'text'
          props.type = button.button || form
          props.attrs = {item: item, server: Server}
        end

        # item overrides
        for name in button
          if name == 'text'
            props.text = button.text
          elsif name == 'class' or name == 'classname'
            props.attrs.className += " #{button[name].gsub('_', '-')}"
          elsif name != 'form'
            props.attrs[name.gsub('_', '-')] = button[name]
          end
        end

        return props
      end
    else
      @buttons = []
    end

    @item = Main.item = item
  end

  # common layout for all pages: header, main, footer, and forms
  def render
    if not @item
      _p 'Not found'
    else

      _Header item: @item

      _main do
        React.createElement(@item.view, item: @item)
      end

      _Footer item: @item, buttons: @buttons, traversal: @traversal

      # emit hidden forms associated with the buttons displayed on this page
      if @item.buttons
        @item.buttons.each do |button|
          if button.form
            React.createElement(button.form, item: @item, server: @@server,
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
    self.route(@@page.path, @@page.query)

    # free memory
    @@page.parsed = nil
  end

  # navigation method that updates history (back button) information
  def navigate(path, query)
    self.route(path, query)
    history.pushState({path: path, query: query}, nil, path)
  end

  # refresh the current page
  def refresh()
    self.route(history.state.path, history.state.query)
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
        self.route(event.state.path, event.state.query)
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

      if event.keyCode == 37
        link = ~"a[rel=prev]"
        self.navigate link.getAttribute('href') if link
      elsif event.keyCode == 39
        link = ~"a[rel=next]"
        self.navigate link.getAttribute('href') if link
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
        self.route(history.state.path, history.state.query)
      end
    end
    xhr.send()
  end
end
