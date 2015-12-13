#
# Encapsulations for asynchronous HTTP requests.  Uses older XMLHttpRequest
# API over fetch as fetch isn't widely supported yet:
# https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API#Browser_compatibility
#


class HTTP
  # "AJAX" style post request to the server, with a callback
  def self.post(target, data, &block)
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
          else
            HTTP._log(xhr)
          end
        rescue => e
          console.log(e)
        end

        block(data)
      end
    end

    xhr.send(JSON.stringify(data))
  end

  # "AJAX" style patch request to the server, with a callback
  def self.patch(target, data, &block)
    xhr = XMLHttpRequest.new()
    xhr.open('PATCH', target, true)
    xhr.setRequestHeader('Content-Type', 'application/json;charset=utf-8')
    xhr.responseType = 'text'

    def xhr.onreadystatechange()
      if xhr.readyState == 4
        data = nil

        begin
          if xhr.status == 200
            data = JSON.parse(xhr.responseText) 
            alert "Exception\n#{data.exception}" if data.exception
          else
            HTTP._log(xhr)
          end
        rescue => e
          console.log(e)
        end

        block(data)
      end
    end

    xhr.send(JSON.stringify(data))
  end

  # "AJAX" style delete request to the server, with a callback
  def self.delete(target, &block)
    xhr = XMLHttpRequest.new()
    xhr.open('DELETE', target, true)

    def xhr.onreadystatechange()
      if xhr.readyState == 4

        begin
          if xhr.status == 404
            alert "Not Found: #{target}"
          else
            HTTP._log(xhr)
          end
        rescue => e
          console.log(e)
        end

        block()
      end
    end

    xhr.send()
  end

  # "AJAX" style get request to the server, with a callback
  def self.get(target, type, &block)
    xhr = XMLHttpRequest.new()

    def xhr.onreadystatechange()
      if xhr.readyState == 4
        data = nil

        begin
          if xhr.status == 200
            if type == :json
              data = xhr.response || JSON.parse(xhr.responseText) 
            else
              data = xhr.responseText
            end
          else
            HTTP._log(xhr)
          end
        rescue => e
          console.log(e)
        end

        block(data)
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

  # common logging
  def self._log(xhr)
    if xhr.status == 404
      alert "Not Found: #{target}"
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
  end
end
