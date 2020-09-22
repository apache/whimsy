#
# Encapsulations for asynchronous HTTP requests.  Uses older XMLHttpRequest
# API over fetch as fetch isn't widely supported yet:
# https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API#Browser_compatibility
#


class HTTP
  # "AJAX" style post request to the server, with a callback
  def self.post(target, data)
    return Promise.new do |resolve, reject|
      xhr = XMLHttpRequest.new()
      xhr.open('POST', target, true)
      xhr.setRequestHeader('Content-Type', 'application/json;charset=utf-8')
      xhr.responseType = 'text'

      def xhr.onreadystatechange()
        if xhr.readyState == 4
          begin
            if xhr.status == 200
              data = JSON.parse(xhr.responseText)
              if data.exception
                reject(data.exception)
              else
                resolve(data)
              end
            else
              HTTP._reject(xhr, reject)
            end
          rescue => e
            reject(e)
          end
        end
      end

      xhr.send(JSON.stringify(data))
    end
  end

  # "AJAX" style patch request to the server, with a callback
  def self.patch(target, data)
    return Promise.new do |resolve, reject|
      xhr = XMLHttpRequest.new()
      xhr.open('PATCH', target, true)
      xhr.setRequestHeader('Content-Type', 'application/json;charset=utf-8')

      def xhr.onreadystatechange()
        if xhr.readyState == 4
          begin
            if xhr.status == 200
              data = JSON.parse(xhr.responseText)
              if data.exception
                reject(data.exception)
              else
                resolve(data)
              end
            elsif xhr.status == 204
              resolve()
            else
              HTTP._reject(xhr, reject)
            end
          rescue => e
            reject(e)
          end
        end
      end

      xhr.send(JSON.stringify(data))
    end
  end

  # "AJAX" style delete request to the server, with a callback
  def self.delete(target)
    return Promise.new do |resolve, reject|
      xhr = XMLHttpRequest.new()
      xhr.open('DELETE', target, true)
      xhr.responseType = 'text'

      def xhr.onreadystatechange()
        if xhr.readyState == 4
          if xhr.status == 200
            resolve()
          else
            HTTP._reject(xhr, reject)
          end
        end
      end

      xhr.send()
    end
  end

  # "AJAX" style get request to the server, with a callback
  def self.get(target, type)
    return Promise.new do |resolve, reject|
      xhr = XMLHttpRequest.new()

      def xhr.onreadystatechange()
        if xhr.readyState == 4
          begin
            if xhr.status == 200
              if type == :json
                data = xhr.response || JSON.parse(xhr.responseText)
              else
                data = xhr.responseText
              end

              resolve data
            else
              HTTP._reject(xhr, reject)
            end
          rescue => e
            reject e
          end
        end
      end

      if target =~ /^https?:/
        xhr.open('GET', target, true)
        xhr.setRequestHeader("Accept", "application/json") if type == :json
      else
        xhr.open('GET', target, true)
      end

      xhr.responseType = type
      xhr.send()
    end
  end

  # common rejection logic
  def self._reject(xhr, reject)
    if not xhr.status
      reject "Server unavailable"
    elsif xhr.status == 404
      reject "Not found"
    else
      console.log xhr.response
      if not xhr.response
        reject "Exception - #{xhr.statusText}"
      elsif xhr.response.exception
        reject "Exception\n#{xhr.response.exception}"
      else
        text = xhr.responseText
        begin
          json = JSON.parse(text)
          text = "Exception: #{json.exception}" if json.exception
        rescue => e
        end
        reject text
      end
    end
  rescue => e
    reject e
  end
end
