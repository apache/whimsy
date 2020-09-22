#
# Replacement for 'a' element which handles clicks events that can be
# processed locally by calling Main.navigate.
#

class Link < Vue
  def render
    Vue.createElement(element, options, @@text)
  end

  def element
    if @@href
      'a'
    else
      'span'
    end
  end

  def options
    result = {attrs: {}}

    if @@href
      result.attrs.href = @@href.gsub(%r{(^|/)\w+/\.\.(/|$)}, '$1')
    end

    result.attrs.rel = @@rel if @@rel
    result.attrs.id = @@id if @@id

    result.on = {click: self.click}

    result
  end

  def click(event)
    return if event.ctrlKey or event.shiftKey or event.metaKey

    href = event.target.getAttribute('href')

    if href =~ %r{^(\.|cache/.*|(flagged/|(shepherd/)?(queue/)?)[-\w]+)$}
      event.stopPropagation()
      event.preventDefault()
      Main.navigate href
      return false
    end
  end
end
