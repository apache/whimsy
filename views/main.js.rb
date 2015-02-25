class Main < React
  def route(path)
    if path
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
    self.route(@@path)
  end

  def navigate(path)
    self.route(path)
    history.pushState({path: path}, nil, path)
    document.getElementsByTagName('title')[0].textContent = @item.title
  end

  def componentDidMount()
    # export navigate method
    Main.navigate = self.navigate

    history.replaceState({path: @@path}, nil, @@path)
    document.getElementsByTagName('title')[0].textContent = @item.title

    window.addEventListener :popstate do |event|
      if event.state and event.state.path
        self.route(event.state.path)
        document.getElementsByTagName('title')[0].textContent = @item.title
      end
    end

    def (document.getElementsByTagName('body')[0]).onkeyup(event)
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
  end

  def componentDidUpdate()
    window.onresize()
  end
end
