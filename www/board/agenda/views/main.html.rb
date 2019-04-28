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
# Main "layout" for the application, houses a single view
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"
  _link rel: 'manifest', href: "../manifest.json?#{@manmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div_.main!

  # force es5 for non-test visitors.  Visitors using browsers that support
  # ServiceWorkers will receive es2017 versions of the script via
  # views/bootstrap.html.erb.
  app = (ENV['RACK_ENV'] == 'test' ? 'app' : 'app-es5')
  _script src: "../#{app}.js?#{@appmtime}", lang: 'text/javascript'

  _.render '#main' do
    _Main server: @server, page: @page
  end
end
