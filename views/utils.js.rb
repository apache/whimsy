# "AJAX" style post request to the server, with a callback
def post(target, data, &block)
  xhr = XMLHttpRequest.new()
  xhr.open('POST', target, true)
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
def fetch(target, type, &block)
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

