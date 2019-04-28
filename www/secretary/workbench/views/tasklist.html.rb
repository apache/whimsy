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

_html do
  _link rel: 'stylesheet', href: "../secmail.css?#{@cssmtime}"

  if @dryrun['exception']

    _h2.bg_danger @dryrun['exception']
    _pre @dryrun['backtrace'].join("\n")

    _script %{
      var message = {status: 'warning'}
      window.parent.frames[0].postMessage(message, '*')
    }
  else

    _header do
      _h1.bg_warning 'Operations to be performed'
    end
  
    _ul.tasklist! do
      @dryrun['tasklist'].each do |task|
        _li do 
          _h3 task['title']

          task['form'].each do |element|
            element.last[:disabled] = true if Hash === element.last
            tag! *element
          end
        end
      end
    end

    if @dryrun['info']
      _div.alert.alert_warning do
        _b 'Note:'
        _span @dryrun['info']
      end
    end

    if @dryrun['warn']
      _div.alert.alert_danger do
        _b 'Warning:'
        _span @dryrun['warn']
       end

      _div.buttons do
        _button.btn.btn_danger.proceed! 'proceed anyway'
        _button.btn.btn_warning.cancel! 'cancel', disabled: true
      end

      _script %{
        var message = {status: 'warning'}
        window.parent.frames[0].postMessage(message, '*')
      }
    else
      _div.buttons do
        _button.btn.btn_primary.proceed! 'proceed'
        _button.btn.btn_warning.cancel! 'cancel'
      end
    end

    _script "var params = #{JSON.generate(params)};"

    _script src: "../tasklist.js?#{@jsmtime}"
  end
end
