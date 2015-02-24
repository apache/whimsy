class Main < React
  def initialize
    @agenda = Agenda.load(@@parsed)
    @next = {text: 'Help', link: 'help'}
    @prev = {text: 'Help', link: 'help'}

    if @@path
      @item = Agenda.find(@@path)
      @prev = {text: @item.prev.title, link: @item.prev.href} if @item.prev
      @next = {text: @item.next.title, link: @item.next.href} if @item.next
      @color = @item.color
      @title = @item.title
    else
      @date = @@agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')
      @title = @date
      @color = 'blank'
      @@agendas.each do |agenda|
        date = agenda[/(\d+_\d+_\d+)/, 1].gsub('_', '-')

        if date > @date and (@next.text == 'Help' or date < @next.text)
          @next = {text: date, link: "../#{date}/"}
        end
      
        if date < @date and (@prev.text == 'Help' or date > @prev.text)
          @prev = {text: date, link: "../#{date}/"}
        end
      end
    end
  end

  def render
    _header.navbar.navbar_fixed_top class: @color do
      _div.navbar_brand @title
      _ul.nav.nav_pills.navbar_right do
        _li.dropdown do
          _a.dropdown_toggle.nav! 'navigation'
        end
      end
    end

    _main do
      if @item
        _pre @item.text
      else
        React.createElement(Index, agenda: @agenda)
      end
    end

    _footer.navbar.navbar_fixed_bottom class: @color do
      _a.backlink.navbar_brand @prev.text, rel: 'prev', href: @prev.link
      _a.nextlink.navbar_brand @next.text, rel: 'next', href: @next.link
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

    document.getElementsByTagName('title')[0].textContent = @title
    window.onresize()
  end

  def componentDidUpdate()
    window.onresize()
  end
end
