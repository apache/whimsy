# A convenient place to stash server data
Server = {}

# controls display of clock in the header
clock_counter = 0

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
          console.log(xhr.response)
          if not xhr.response
            alert "Exception - #{xhr.statusText}"
          elsif xhr.response.exception
            alert "Exception\n#{xhr.response.exception}"
          else
            alert "Exception\n#{JSON.parse(xhr.responseText).exception}"
          end
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
      clock_counter += 1
      setTimeout(0) {Main.refresh()}
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
          console.log(xhr.response)
          if not xhr.response
            alert "Exception - #{xhr.statusText}"
          elsif xhr.response.exception
            alert "Exception\n#{xhr.response.exception}"
          else
            alert "Exception\n#{JSON.parse(xhr.responseText).exception}"
          end
        end
      rescue => e
        console.log(e)
      end

      block(data)
      clock_counter -= 1
      Main.refresh()
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
    # join consecutive lines (making exception for <markers> like <private>)
    text.gsub! /([^\s>])\n(\w)/, '$1 $2'

    # reflow each line
    lines = text.split("\n")
    len = 78 - indent.length
    for i in 0...lines.length
      indent = lines[i].match(/( *)(.?.?)(.*)/m)

      if (indent[1] == '' and indent[2] != '* ') or indent[3] == ''
        # not indented (or short) -> split
        lines[i] = lines[i].
          gsub(/(.{1,#{len}})( +|$\n?)|(.{1,#{len}})/, "$1$3\n").
          sub(/[\n\r]+$/, '')
      else
        # preserve indentation.  indent[2] is the 'bullet' (if any) and is
        # only to be placed on the first line.
        n = 76 - indent[1].length;
        lines[i] = indent[3].
          gsub(/(.{1,#{n}})( +|$\n?)|(.{1,#{n}})/, indent[1] + "  $1$3\n").
          sub(indent[1] + '  ', indent[1] + indent[2]).
          sub(/[\n\r]+$/, '')
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

