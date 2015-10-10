#
# Replacement for 'a' element which handles clicks events that can be
# processed locally by calling Main.navigate.
#

class Link < React
  def initialize
    @attrs = {}
  end

  def componentWillMount()
    self.componentWillReceiveProps()
    @attrs.onClick = self.click
  end

  def componentWillReceiveProps(props)
    @text = props.text

    for attr in props
      next unless props[attr]
      @attrs[attr] = props[attr] unless attr == 'text'
    end

    if props.href
      @element = 'a'
      @attrs.href = props.href.gsub(%r{(^|/)\w+/\.\.(/|$)}, '$1')
    else
      @element = 'span'
    end
  end

  def render
    React.createElement(@element, @attrs, @text)
  end

  def click(event)
    return if event.ctrlKey or event.shiftKey or event.metaKey

    href = event.target.getAttribute('href')

    if href =~ %r{^(\.|(flagged/|(shepherd/)?(queue/)?)[-\w]+)$}
      event.stopPropagation()
      event.preventDefault()
      Main.navigate href
      return false
    end
  end
end
