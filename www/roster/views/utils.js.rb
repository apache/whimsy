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

class Utils

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
