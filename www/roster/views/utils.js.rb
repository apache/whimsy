class Utils

  # escape a string so that it can be used as a regular expression
  def self.escapeRegExp(string)
    # https://developer.mozilla.org/en/docs/Web/JavaScript/Guide/Regular_Expressions
    return string.gsub(/([.*+?^=!:${}()|\[\]\/\\])/, "\\$1");
  end

  # Common processing to handle a response that is expected to be JSON
  def self.handle_json(response, success)
    content_type = response.headers.get('content-type') || ''
    isJson = content_type.include? 'json'
    if response.status == 200 and isJson
      response.json().then do |json|
        success json
      end
    else
      footer = 'See server log for full details'
      if isJson
        response.json().then do |json|
          # Pick out the exception
          message = json['exception'] || ''
          alert "#{response.status} #{response.statusText}\n#{message}\n#{footer}"
        end
      else # not JSON
        response.text() do |text|
          alert "#{response.status} #{response.statusText}\n#{text}\n#{footer}"
        end
      end
    end
  end
end
