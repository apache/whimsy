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
# A single Podling PMC
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _title  @ppmc[:display_name]

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        ppmc: 'ppmc/',
        @ppmc[:id] => "ppmc/#{@ppmc[:id]}"
      }
    ) do
      _div_.main!
      _script src: "app.js?#{appmtime}"
      _.render '#main' do
        _PPMC ppmc: @ppmc, auth: @auth
      end
    end
  end
end
