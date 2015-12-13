class Calendar < React
  def render
    _section do
      days = Date.new(@year, @month+1, 0).getDate()
      start = Date.new(@year, @month).getDay()
      months = %w(January February March April May June July August
        September October November December)

      _header "#{months[@month]} #{@year}"

      _ol.calendar! do
        for i in 1..start
          _li.spacer
        end

        for i in 1..days
          _li do
            _div.day i
            if @items[i]
              _ul @items[i] do |item|
                _li item
              end
            end
          end
        end
      end
    end
  end

  # copy Element properties to state
  def componentWillMount()
    this.setState(this.props)
  end

  def componentDidMount()
    # listen for up/down keys
    window.addEventListener(:keydown) do |event|
      if event.keyCode == 37
        self.setDate(Date.new(@year, @month-1), true)
      elsif event.keyCode == 39
        self.setDate(Date.new(@year, @month+1), true)
      end
    end

    # back button support
    history.replaceState({year: @year, month: @month}, 'title', location)
    window.addEventListener(:popstate) do |event|
      self.setDate(Date.new(event.state.year, event.state.month), false)
    end
  end

  # change the page
  def setDate(date, push)
    @year = date.getYear()+1900
    @month = date.getMonth()
    @items = {}

    if push
      url = "#{@year}/#{@month < 9 ? "0#{@month+1}" : @month+1}"
      history.pushState({year: @year, month: @month}, 'title', url)
    end

    # request a list of calendar items for this month
    request = XMLHttpRequest.new()
    request.open('GET', "#{window.location}.json", true)
    def request.onreadystatechange()
      return unless request.readyState == 4 and request.status == 200
      @items = JSON.parse(request.responseText)
    end
    request.send()
  end
end
