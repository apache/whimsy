# A convenient place to stash server data
Server = {}

# Escape HTML characters so that raw text can be safely inserted as HTML
def htmlEscape(string)
  return string.gsub(htmlEscape.chars) {|c| htmlEscape.replacement[c]}
end

htmlEscape.chars = Regexp.new('[&<>]', 'g')
htmlEscape.replacement = {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;'}

# Replace http[s] links in text with anchor tags
def hotlink(string)
  return string.gsub hotlink.regexp do |match, pre, link|
    "#{pre}<a href='#{link}'>#{link}</a>"
  end
end

hotlink.regexp = Regexp.new(/(^|[\s.:;?\-\]<\(])
  (https?:\/\/[-\w;\/?:@&=+$.!~*'()%,#]+[\w\/])
  (?=$|[\s.:,?\-\[\]&\)])/x, "g")

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
        elsif xhr.status >= 400
          console.log(xhr.responseText)
          alert "Exception\n#{JSON.parse(xhr.responseText).exception}"
        end
      rescue => e
        console.log(e)
      end

      block(data)
    end
  end

  xhr.send(JSON.stringify(data))
end
