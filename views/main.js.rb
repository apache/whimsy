class Main < React
  def initialize
    @poll = {
      link: "../#{@@agenda[/(\d+_\d+_\d+)/,1].gsub('_','-')}.json",
      etag: @@etag,
      interval: 10_000
    }
  end

  def route(path, query)
    if path == 'search'
      @item = {title: 'Search', view: Search, color: 'blank', query: query}
    elsif path == 'comments'
      @item = {title: 'Comments', view: Comments, color: 'blank'}
    elsif path and path != '.'
      @item = Agenda.find(path)
    else
      @item = Agenda
    end
  end

  def render
    _Header item: @item

    _main do
      React.createElement(@item.view, data: @item)
    end

    _Footer item: @item
  end

  def componentWillMount()
    Agenda.load(@@parsed)
    Agenda._date = @@agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')
    Agenda._agendas = @@agendas
    self.route(@@path, @@query)
  end

  def navigate(path, query)
    self.route(path, query)
    history.pushState({path: path, query: query}, nil, path)
  end

  def componentDidMount()
    # export navigate method
    Main.navigate = self.navigate

    if not history.state or not history.state.query
      history.replaceState({path: @@path}, nil, @@path)
    end

    window.addEventListener :popstate do |event|
      if event.state and defined? event.state.path
        self.route(event.state.path, event.state.query)
      end
    end

    def (document.getElementsByTagName('body')[0]).onkeyup(event)
      return if document.getElementById('search-text')

      if event.keyCode == 37
        self.navigate document.querySelector("a[rel=prev]").getAttribute('href')
      elsif event.keyCode == 39
        self.navigate document.querySelector("a[rel=next]").getAttribute('href')
      end
    end

    def window.onresize()
      main = document.querySelector('main')
      header = document.querySelector('header.navbar')
      footer = document.querySelector('header.navbar')
      main.style.marginTop = "#{header.clientHeight}px"
      main.style.marginBottom = "#{footer.clientHeight}px"
    end

    window.onresize()

    self.pollAgenda() unless @poll.etag
    setInterval self.pollAgenda, @poll.interval
  end

  def pollAgenda()
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

  def componentDidUpdate()
    window.onresize()
  end
end
