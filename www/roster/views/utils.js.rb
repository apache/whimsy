class Utils
  # Common processing to handle a response
  # called from e.g. fetch($options.add_action, args).then {|response| ...
  def self.handle_response(response)
    content_type = response.headers.get('content-type') || ''
    isJson = content_type.include? 'json'
    if response.status == 200 and isJson
      response.json().then do |json|
        Vue.emit :update, json
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
