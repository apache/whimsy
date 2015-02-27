class Search < React
  def initialize
    @text = @@data.query || ''
  end

  def render
    _div.search do
      _label 'Search:', for: 'search_text'
      _input.search_text! autofocus: 'autofocus', value: @text, 
        onInput: self.input
    end

    if @text.length > 2
      matches = false
      text = @text.downcase()

      Agenda.index.each do |item|
        next unless item.text and item.text.downcase().include? text
        matches = true

        _section do
          _h4 {_Link text: item.title, href: item.href}

          item.text.split(/\n\s*\n/).each do |paragraph|
            if paragraph.downcase().include? text
              paragraph = paragraph.gsub('&', '&amp;').gsub('>', '&gt;').
                gsub('<', '&lt;')

              _pre.report dangerouslySetInnerHTML: {
                __html: paragraph.gsub(/(#{text})/i,
                 "<span class='hilite'>$1</span>")
              }
            end
          end
        end
      end

      _p {_em 'No matches'} unless matches
    else
      _p 'Please enter at least three characters'
    end
  end

  def input(event)
    @text = event.target.value
  end

  def componentDidMount()
    self.componentDidUpdate()
  end

  def componentDidUpdate()
    state = {path: 'search', query: @text}

    if state.query
      history.replaceState(state, nil, "search?q=#{encodeURIComponent(@text)}")
    else
      history.replaceState(state, nil, 'search')
    end
  end
end
