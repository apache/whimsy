require_relative 'vue-config'

require_relative 'main'
require_relative 'pages'

# A convenient place to stash server data
Server = {}

# Form data for demo purposes
FormData = {
  fullname: 'Joe Test',
  email: 'joetest@example.com',
  pmc: 'incubator',
  votelink: 'dummy'
}

# "AJAX" style post request to the server, with a callback
def post(target, data, &block)
  xhr = XMLHttpRequest.new()
  xhr.open('POST', "actions/#{target}", true)
  xhr.setRequestHeader('Content-Type', 'application/json;charset=utf-8')
  xhr.responseType = 'text'

  def xhr.onreadystatechange()
    if xhr.readyState == 4
      data = nil

      begin
        if xhr.status == 200
          data = JSON.parse(xhr.responseText)
        elsif xhr.status == 404
          alert "Not Found: actions/#{target}"
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
