#
# Escape text for inclusion in HTML; optionally apply filters
#

class Text < Vue
  def render
    _span domPropsInnerHTML: text
  end

  def text
    result = htmlEscape(@@raw || '')

    if @@filters
      @@filters.each { |filter| result = filter(result) }
    end

    result
  end
end
