# A convenient place to stash server data
Server = {}

#
# function to assist with production of HTML and regular expressions
#

# Escape HTML characters so that raw text can be safely inserted as HTML
def htmlEscape(string)
  return string.gsub(htmlEscape.chars) {|c| htmlEscape.replacement[c]}
end

htmlEscape.chars = Regexp.new('[&<>]', 'g')
htmlEscape.replacement = {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;'}

# escape a string so that it can be used as a regular expression
def escapeRegExp(string)
  # https://developer.mozilla.org/en/docs/Web/JavaScript/Guide/Regular_Expressions
  return string.gsub(/([.*+?^=!:${}()|\[\]\/\\])/, "\\$1");
end

# Replace http[s] links in text with anchor tags
def hotlink(string)
  return string.gsub hotlink.regexp do |match, pre, link|
    "#{pre}<a href='#{link}'>#{link}</a>"
  end
end

hotlink.regexp = Regexp.new(/(^|[\s.:;?\-\]<\(])
  (https?:\/\/[-\w;\/?:@&=+$.!~*'()%,#]+[\w\/])
  (?=$|[\s.:;,?\-\[\]&\)])/x, "g")

#
# Requests to the server
#

# "AJAX" style post request to the server, with a callback
def post(target, data, &block)
  xhr = XMLHttpRequest.new()
  xhr.open('POST', "../json/#{target}", true)
  xhr.setRequestHeader('Content-Type', 'application/json;charset=utf-8')
  xhr.responseType = 'text'

  def xhr.onreadystatechange()
    if xhr.readyState == 4
      data = nil

      begin
        if xhr.status == 200
          data = JSON.parse(xhr.responseText) 
          alert "Exception\n#{data.exception}" if data.exception
        elsif xhr.status == 404
          alert "Not Found: json/#{target}"
        elsif xhr.status >= 400
          if not xhr.response
            message = "Exception - #{xhr.statusText}"
          elsif xhr.response.exception
            message = "Exception\n#{xhr.response.exception}"
          else
            message = "Exception\n#{JSON.parse(xhr.responseText).exception}"
          end

          console.log(message)
          alert message
        end
      rescue => e
        console.log(e)
      end

      block(data)
      Main.refresh()
    end
  end

  xhr.send(JSON.stringify(data))
end

# "AJAX" style get request to the server, with a callback
#
# Would love to use/build on 'fetch', but alas:
#
#   https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API#Browser_compatibility 
def retrieve(target, type, &block)
  xhr = XMLHttpRequest.new()

  def xhr.onreadystatechange()
    if xhr.readyState == 1
      Header.clock_counter += 1
    elsif xhr.readyState == 4
      data = nil

      begin
        if xhr.status == 200
          if type == :json
            data = xhr.response || JSON.parse(xhr.responseText) 
          else
            data = xhr.responseText
          end
        elsif xhr.status == 404
          alert "Not Found: #{type}/#{target}"
        elsif xhr.status >= 400
          if not xhr.response
            message = "Exception - #{xhr.statusText}"
          elsif xhr.response.exception
            message = "Exception\n#{xhr.response.exception}"
          else
            message = "Exception\n#{JSON.parse(xhr.responseText).exception}"
          end

          console.log(message)
          alert(message)
        end
      rescue => e
        console.log(e)
      end

      block(data)
      Header.clock_counter -= 1
    end
  end

  if target =~ /^https?:/
    xhr.open('GET', target, true)
    xhr.setRequestHeader("Accept", "application/json") if type == :json
  else
    xhr.open('GET', "../#{type}/#{target}", true)
  end
  xhr.responseType = type
  xhr.send()
end

#
# Reflow comments and lines
#

class Flow
  # reflow comment
  def self.comment(comment, initials, indent='    ')
    lines = comment.split("\n")
    len = 71 - indent.length
    for i in 0...lines.length
      lines[i] = (i == 0 ? initials + ': ' : "#{indent} ") + lines[i].
        gsub(/(.{1,#{len}})( +|$\n?)|(.{1,#{len}})/, "$1$3\n#{indent}").
        trim()
    end
    return lines.join("\n")
  end

  # reflow text
  def self.text(text, indent='')
    # remove trailing spaces on lines
    text.gsub! /[ \r\t]+\n/, "\n"

    # join consecutive lines (making exception for <markers> like <private>)
    text.gsub! /([^\s>])\n[ \t]*(\w)/, '$1 $2'

    # reflow each line
    lines = text.split("\n")
    len = 78 - indent.length
    for i in 0...lines.length
      line = lines[i]
      next if line.length <= len
      prefix = /^\W*/.exec(line)[0]

      if prefix.length == 0
        # not indented -> split
        lines[i] = line.
          gsub(/(.{1,#{len}})( +|$\n?)/, "$1\n").
          sub(/[\n\r]+$/, '')
      else
        # preserve indentation.
        n = len - prefix.length;
        indent = prefix.gsub(/\W/, ' ')
        lines[i] = prefix + line[prefix.length..-1].
          gsub(/(.{1,#{n}})( +|$\n?)/, indent + "$1\n").
          sub(indent, '').sub(/[\n\r]+$/, '')
      end
    end

    return lines.join("\n")
  end
end

#
# Split comments string into individual comments
#

def splitComments(string)
  results = []
  return results unless string

  comment = ''
  string.split("\n").each do |line|
    if line =~ /^\S/
      results << comment unless comment.empty?
      comment = line
    else
      comment += "\n" + line
    end
  end

  results << comment unless comment.empty?
  return results
end

