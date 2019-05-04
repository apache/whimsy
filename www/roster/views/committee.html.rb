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

#
# A single committee
#

_html do
  _base href: '..'
  _title @committee[:display_name]
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        committee: 'committee/',
        @committee[:id] => "committee/#{@committee[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main' do
      _PMC committee: @committee, auth: @auth
    end
  end
end
