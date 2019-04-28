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
# Post a new agenda
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div.container.new_agenda! do
    _form method: 'post',  action: @meeting.strftime("%Y-%m-%d/") do

      _div.text_center do
        _button.btn.btn_primary 'Post', disabled: @disabled
      end

      _textarea.form_control @agenda, name: 'agenda',
        rows: [@agenda.split("\n").length, 20].max
    end
  end
end
