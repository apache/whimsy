##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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
