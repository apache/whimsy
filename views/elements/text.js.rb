#
# Escape text for inclusion in HTML; optionally apply filters
#

class Text < React
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  def componentWillReceiveProps()
    @text = htmlEscape(@@raw)

    if @@filters
      @@filters.each { |filter| @text = filter(@text) }
    end
  end

  def render
    _span dangerouslySetInnerHTML: { __html: @text }
  end
end
