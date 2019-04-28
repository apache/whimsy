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

class Attic
  def self.issues
    @issues = nil if @mtime and Time.now - @mtime > 300

    unless @issues
      require 'cgi'
      query = 'project = ATTIC AND status in (Open, "In Progress", Reopened)'

      uri = URI.parse('https://issues.apache.org/jira/rest/api/2/search?jql=')

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri.request_uri + CGI.escape(query))

        response = http.request(request)

        @issues = JSON.parse(response.body)['issues'].map do |issue|
          [ issue['key'], issue['fields']['summary'] ]
        end
      end
      @mtime = Time.now
    end

    Hash[@issues]
  end
end
