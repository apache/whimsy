class Main < React
  def initialize
    Agenda.load(@@parsed)

    if @@path
      @item = Agenda.find(@@path)
    else
      Agenda._date = @@agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')
      Agenda._agendas = @@agendas
      @item = Agenda
    end
  end

  def render
    _header.navbar.navbar_fixed_top class: @item.color do
      _div.navbar_brand @item.title
      _ul.nav.nav_pills.navbar_right do
        _li.dropdown do
          _a.dropdown_toggle.nav! 'navigation'
        end
      end
    end

    _main do
      React.createElement(@item.view, data: @item)
    end

    _footer.navbar.navbar_fixed_bottom class: @item.color do
      if @item.prev
        _a.backlink.navbar_brand @item.prev.title, rel: 'prev', 
         href: @item.prev.href
      end
      if @item.next
        _a.nextlink.navbar_brand @item.next.title, rel: 'next', 
         href: @item.next.href
      end
    end
  end

  def componentDidMount()
    def window.onresize()
      main = document.querySelector('main')
      header = document.querySelector('header.navbar')
      footer = document.querySelector('header.navbar')
      main.style.marginTop = "#{header.clientHeight}px"
      main.style.marginBottom = "#{footer.clientHeight}px"
    end

    document.getElementsByTagName('title')[0].textContent = @item.title
    window.onresize()
  end

  def componentDidUpdate()
    window.onresize()
  end
end
