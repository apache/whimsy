#
# Search component:
#  * prompt for search
#  * display matching paragraphs from agenda, highlighting search strings
#  * keep query string in window location URL in synch
#

class Search < Vue
  # initialize query text based on data passed to the component
  def initialize
    @text = @@item.query || ''
  end

  def render
    # search input field
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

          # highlight matching strings in paragraph
          item.text.split(/\n\s*\n/).each do |paragraph|
            if paragraph.downcase().include? text
              _pre.report domPropsInnerHTML:
                htmlEscape(paragraph).gsub(/(#{escapeRegExp(text)})/i,
                 "<span class='hilite'>$1</span>")
            end
          end
        end
      end

      # if no sections were output, indicate 'no matches'
      _p {_em 'No matches'} unless matches
    else

      # start producing query results when input string has three characters
      _p 'Please enter at least three characters'

    end
  end

  # update text whenever input changes
  def input(event)
    @text = event.target.value
  end

  # set history on initial rendering
  def mounted()
    self.updateHistory()
  end

  # replace history state on subsequent renderings
  def updated()
    self.updateHistory()
  end

  def updateHistory()
    state = {path: 'search', query: @text}

    if state.query
      history.replaceState(state, nil, "search?q=#{encodeURIComponent(@text)}")
    else
      history.replaceState(state, nil, 'search')
    end
  end
end
