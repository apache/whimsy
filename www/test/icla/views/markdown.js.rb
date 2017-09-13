#
# Convert markdown to html
#

class Markdown < Vue
  def render
    _span domPropsInnerHTML: html
  end

  def html
    # trim leading and trailing spaces
    text = @@text.sub(/^\s*\n/, '').sub(/\s+$/, '')

    # normalize indentation
    spaces = new RegExp('^ *\S', 'mg');
    match = regexp.exec(text)
    if match
      indent = match[0].length - 1
      while (match = regexp.exec(text))
        indent = match[0].length - 1 if indent >= match[0].length
      end

      if indent > 0
        spaces = Array.new(indent+1).join(' ')
        text = text.replace(new Regexp("^#{spaces}", 'g'), '')
      end
    end

    # convert markdown to text
    markd(text)
  end
end
